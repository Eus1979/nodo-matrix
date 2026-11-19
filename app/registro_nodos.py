#!/usr/bin/env python3
"""
NODOS — App de registro (captura de datos con interfaz amigable).

Complemento del panel de monitoreo: aquí se registra la actividad real de
la red — nodos, miembros, movimientos, asambleas, proyectos y talentos —
con formularios simples y el reglamento RGL-NOD-001 validando de verdad.

Modo demo (sin base de datos ni drivers, para probar la interfaz):
    NODOS_DEMO=1 python3 registro_nodos.py

Modo real (escribe en la base 'nodos'; necesita driver):
    sudo pacman -S python-psycopg2             # CachyOS/Arch
    o pip install 'psycopg[binary]'

Contraseña de la base (solo una vez):
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'TU_CLAVE';"

Arranque:
    python3 registro_nodos.py --password TU_CLAVE                 # local
    python3 registro_nodos.py --password TU_CLAVE --host 0.0.0.0  # y el celular
        → http://IP-de-esta-PC:8081 → Chrome preferido → "Añadir a pantalla
          de inicio" para usarla como app.
"""
import argparse
import json
import os
import sys
import threading
import time
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

BASE = Path(__file__).resolve().parent
STATIC = BASE / "static"
ARGS = None
_lock = threading.Lock()
_cache = {"ts": 0.0, "catalogos": None}


# ---------------------------------------------------------------- drivers
class PsycopgLikeStorage:
    def __init__(self):
        import importlib
        mod = None
        for nombre in ("psycopg2", "psycopg"):
            try:
                mod = importlib.import_module(nombre)
                break
            except ImportError:
                continue
        if mod is None:
            sys.exit("""Falta el driver de PostgreSQL:
  sudo pacman -S python-psycopg2      (CachyOS/Arch)
  o pip install 'psycopg[binary]'
También puedes probar la interfaz sin instalar nada:
  NODOS_DEMO=1 python3 registro_nodos.py""")
        kw = dict(dbname=ARGS.db, user=ARGS.user, port=ARGS.dbport)
        if ARGS.dbhost: kw["host"] = ARGS.dbhost
        if ARGS.password: kw["password"] = ARGS.password
        self.conn = mod.connect(**kw)
        self.conn.autocommit = True

    def query(self, sql, params=()):
        cur = self.conn.cursor()
        cur.execute(sql, params)
        if cur.description is None:
            return []
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, r)) for r in cur.fetchall()]

    def execute(self, sql, params=()):
        self.query(sql, params)


class DemoStorage:
    """Base ficticia en memoria para ver la app sin PostgreSQL."""

    def __init__(self):
        i = iter(range(1, 10_000))
        self._next = lambda: next(i)
        self.nodos = [
            {"id": 1, "codigo": "NODO-RAIZ-001", "nombre": "NODO Raíz Nacional", "etapa": "activo"},
            {"id": 2, "codigo": "NODO-OESTE-100", "nombre": "NODO Barrio Oeste", "etapa": "organizar"},
        ]
        self.valores = ["Honestidad", "Empatía", "Respeto mutuo", "Transparencia",
                        "Cooperación ganar-ganar", "Vocación de servicio"]
        self.miembros = [
            {"id": 11, "nombre": "María Rondón", "nodo": 2, "estado": "activo"},
            {"id": 12, "nombre": "José Pérez", "nodo": 2, "estado": "activo"},
        ]
        self.movimientos = [
            {"id": 21, "nodo": 2, "tipo": "ingreso", "monto": 500, "moneda": "USD",
             "descripcion": "Aporte inicial", "soporte": None, "estado": "aprobado", "verificaciones": 2},
        ]
        self.talentos = ["Administración contable", "Herramientas digitales"]
        self.miembro_talento = []
        self.alertas = []

    def catalogos(self):
        return {"nodos": self.nodos, "valores": self.valores, "miembros": self.miembros,
                "talentos": self.talentos, "alertas": self.alertas,
                "ultimo": getattr(self, "_ultimo", None)}

    def registro(self, tipo, d):
        self._ultimo = {"tipo": tipo, "fecha": time.strftime("%H:%M:%S")}
        if tipo == "nodo":
            n = {"id": self._next(), "codigo": d["codigo"], "nombre": d["nombre"], "etapa": d.get("etapa", "reunir")}
            self.nodos.append(n)
            return "NODO %s registrado — etapa inicial: %s" % (n["nombre"], n["etapa"])
        if tipo == "miembro":
            m = {"id": self._next(), "nombre": d["nombres"], "nodo": d["nodo"], "estado": "activo"}
            self.miembros.append(m)
            return "Miembro %s registrado con %d valores declarados (filtro ético Art. 1)" % (m["nombre"], len(d.get("valores") or []))
        if tipo == "movimiento":
            mv = {"id": self._next(), "nodo": d["nodo"], "tipo": d["tipo"], "monto": d["monto"],
                  "moneda": d.get("moneda", "USD"), "descripcion": d["descripcion"],
                  "soporte": d.get("soporte") or None, "estado": "registrado", "verificaciones": 0}
            self.movimientos.append(mv)
            nota = " — necesitará factura antes de poder aprobarse (Art. 4)" if (mv["tipo"] == "egreso" and not mv["soporte"]) else ""
            return "Movimiento %s de %s %s registrado (id %d)%s" % (mv["tipo"], mv["monto"], mv["moneda"], mv["id"], nota)
        if tipo == "verificacion":
            for mv in self.movimientos:
                if mv["id"] == d["movimiento"]:
                    mv["verificaciones"] = mv.get("verificaciones", 0) + (1 if d["resultado"] else 0)
                    if mv["verificaciones"] >= 2 and mv.get("soporte"):
                        mv["estado"] = "aprobado"
            return "Verificación registrada: el verificador nunca puede ser el registrador (Art. 4)"
        if tipo == "reunion":
            if not (d.get("puntos") or []):
                raise ValueError("La agenda es obligatoria y debe publicarse antes de la reunión (Art. 2)")
            return "Asamblea %s publicada con %d puntos de agenda (Art. 2)" % (d["titulo"], len(d["puntos"]))
        if tipo == "actividad":
            if d.get("titular") == d.get("suplente"):
                raise ValueError("Titular y suplente deben ser personas distintas (Art. 5)")
            return "Actividad %s dejada con titular y suplente (Art. 5)" % d["titulo"]
        if tipo == "talento":
            if d.get("miembro"):
                self.miembro_talento.append({d["miembro"]: d["talento"]})
            return "Talento mapeado — quién sabe, enseña"
        raise ValueError("Tipo de registro desconocido: %s" % tipo)


_storage = None
def storage():
    global _storage
    if _storage is None:
        _storage = DemoStorage() if os.environ.get("NODOS_DEMO") == "1" else PsycopgLikeStorage()
    return _storage


# -------------------------------------------------------- operaciones SQL
OPS = {
    "nodo": """
        INSERT INTO nodos.nodo (codigo, nombre, tipo_nodo_id, nodo_padre_id, sector, pais, etapa)
        VALUES (%(codigo)s, %(nombre)s,
                (SELECT id FROM nodos.tipo_nodo WHERE clave = %(tipo_nodo)s),
                NULLIF(%(nodo_padre)s, '')::int,
                %(sector)s, %(pais)s, %(etapa)s)
        RETURNING id
    """,
    "miembro": """
        INSERT INTO nodos.miembro (nodo_id, nombres, documento_ci, contacto, estado, antecedentes_verificados)
        VALUES (%(nodo)s, %(nombres)s, %(ci)s, NULLIF(%(contacto)s, ''), 'activo', %(antecedentes)s)
        RETURNING id
    """,
    "movimiento": """
        INSERT INTO nodos.movimiento_financiero
            (nodo_id, tipo, monto, moneda, descripcion, registrado_por_id, soporte_referencia, estado)
        VALUES (%(nodo)s, %(tipo)s, %(monto)s, %(moneda)s, %(descripcion)s,
                %(registrador)s, NULLIF(%(soporte)s, ''), 'registrado')
        RETURNING id
    """,
    "verificacion": """
        INSERT INTO nodos.verificacion_movimiento (movimiento_id, verificador_id, resultado, observaciones)
        VALUES (%(movimiento)s, %(verificador)s, %(resultado)s, NULLIF(%(observaciones)s, ''))
    """,
    "reunion": """
        INSERT INTO nodos.reunion
            (nodo_id, titulo, fecha, agenda_publicada, publicada_en, moderador_id, minutos_por_persona)
        VALUES (%(nodo)s, %(titulo)s, %(fecha)s::timestamptz, true, now(), %(moderador)s, 3)
        RETURNING id
    """,
    "actividad": """
        INSERT INTO nodos.actividad (nodo_id, tipo, titulo, descripcion, titular_id, suplente_id, estado)
        VALUES (%(nodo)s, %(tipo_actividad)s, %(titulo)s, NULLIF(%(descripcion)s, ''),
                %(titular)s, %(suplente)s, 'planificado')
        RETURNING id
    """,
}


def registrar(tipo, d):
    try:
        with _lock:
            if isinstance(storage(), DemoStorage):
                return {"ok": True, "mensaje": storage().registro(tipo, d)}
            if tipo == "nodo":
                new = storage().query(OPS[tipo], d)[0]["id"]
                return {"ok": True, "mensaje": "NODO %s registrado — etapa %s" % (d["nombre"], d["etapa"]), "id": new}
            if tipo == "miembro":
                new = storage().query(OPS[tipo], d)[0]["id"]
                for v in d.get("valores") or []:
                    storage().query("""INSERT INTO nodos.miembro_valor (miembro_id, valor_id)
                                       SELECT %s, id FROM nodos.valor WHERE nombre = %s
                                       ON CONFLICT DO NOTHING""", (new, v))
                storage().query("""INSERT INTO nodos.declaracion_conducta (miembro_id, compromiso)
                                   SELECT %s, 'Compromiso NODOS: sin proselitismo político-partidista y sin interés propio.'
                                   ON CONFLICT (miembro_id) DO NOTHING""", (new,))
                return {"ok": True, "mensaje": "Miembro %s registrado con %d valores declarados (Art. 1)" % (d["nombres"], len(d.get("valores") or [])), "id": new}
            if tipo == "movimiento":
                new = storage().query(OPS[tipo], d)[0]["id"]
                return {"ok": True, "mensaje": "Movimiento %s de %s %s registrado (id %d) — requiere doble verificación para aprobarse (Art. 4)" % (d["tipo"], d["monto"], d.get("moneda", "USD"), new), "id": new}
            if tipo == "verificacion":
                storage().query(OPS[tipo], d)
                aprob = storage().query("""SELECT estado FROM nodos.movimiento_financiero WHERE id = %s""", (d["movimiento"],))
                return {"ok": True, "mensaje": "Verificación anotada — estado actual: %s. El verificador siempre es distinto del registrador." % (aprob[0]["estado"] if aprob else "?")}
            if tipo == "reunion":
                new = storage().query(OPS[tipo], d)[0]["id"]
                for orden, punto in enumerate(d.get("puntos") or [], start=1):
                    storage().query("INSERT INTO nodos.punto_agenda (reunion_id, orden, tema) VALUES (%s, %s, %s)", (new, orden, punto))
                return {"ok": True, "mensaje": "Asamblea publicada con agenda previa y máx. 3 min por persona (Art. 2)", "id": new}
            if tipo == "actividad":
                new = storage().query(OPS[tipo], d)[0]["id"]
                return {"ok": True, "mensaje": "Actividad %s abierta con titular y suplente (Art. 5)" % d["titulo"], "id": new}
            if tipo == "talento":
                storage().query("""INSERT INTO nodos.miembro_talento (miembro_id, talento_id, puede_ensenar)
                                   SELECT %s, id, %s FROM nodos.talento WHERE nombre = %s
                                   ON CONFLICT (miembro_id, talento_id)
                                   DO UPDATE SET puede_ensenar = EXCLUDED.puede_ensenar""",
                                (d["miembro"], bool(d.get("ensena")), d["talento"]))
                return {"ok": True, "mensaje": "Talento mapeado — quién sabe, enseña"}
            return {"ok": False, "error": "Tipo de registro desconocido: %s" % tipo}
    except ValueError as e:
        return {"ok": False, "error": str(e)}
    except Exception as e:
        diag = getattr(e, "diag", None)
        msg = getattr(diag, "message_primary", None) or str(e).splitlines()[0]
        return {"ok": False, "error": msg}


def catalogos():
    now = time.time()
    with _lock:
        if _cache["catalogos"] and now - _cache["ts"] < 5:
            return _cache["catalogos"]
    if isinstance(storage(), DemoStorage):
        out = storage().catalogos()
    else:
        out = {}
        out["nodos"] = storage().query("SELECT id, codigo, nombre, etapa FROM nodos.nodo WHERE activo ORDER BY id")
        out["valores"] = [r["nombre"] for r in storage().query("SELECT nombre FROM nodos.valor ORDER BY id")]
        out["miembros"] = storage().query("""SELECT m.id, m.nombres AS nombre, m.nodo_id AS nodo
                                             FROM nodos.miembro m WHERE m.estado = 'activo' ORDER BY m.id""")
        out["talentos"] = [r["nombre"] for r in storage().query("SELECT nombre FROM nodos.talento ORDER BY id")]
        alertas = []
        alertas += storage().query("SELECT 'transparencia'::text AS tipo, nodo_codigo, alerta AS detalle FROM nodos.vw_alerta_transparencia")
        alertas += storage().query("SELECT 'custodia'::text AS tipo, nodo_codigo, nombre || ': ' || custodios_actuales || '/' || custodios_minimos || ' custodios' AS detalle FROM nodos.vw_alerta_custodia")
        alertas += storage().query("SELECT 'continuidad'::text AS tipo, nodo_codigo, detalle FROM nodos.vw_alerta_continuidad")
        alertas += storage().query("SELECT 'backup'::text AS tipo, nodo_codigo, nombre || ': sin respaldo vigente' AS detalle FROM nodos.vw_backup_vencidos")
        out["alertas"] = alertas
    _cache["ts"] = now
    _cache["catalogos"] = out
    return out


# ---------------------------------------------------------------- servidor
class Handler(BaseHTTPRequestHandler):
    def _send(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False, default=str).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _file(self, nombre, ctype):
        p = STATIC / nombre
        try:
            body = p.read_bytes()
        except FileNotFoundError:
            self._send({"error": "no encontrado"}, 404); return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        ruta = self.path.split("?")[0]
        if ruta == "/api/catalogos":
            try:
                self._send(catalogos())
            except Exception as e:
                self._send({"ok": False, "error": str(e).splitlines()[0]}, 500)
        elif ruta == "/manifest.webmanifest":
            self._send({"name": "NODOS Registro", "short_name": "NODOS", "start_url": "/",
                        "display": "standalone", "background_color": "#0b0f14",
                        "theme_color": "#22c55e"})
        elif ruta in ("/", "/index.html"):
            self._file("index.html", "text/html; charset=utf-8")
        elif ruta == "/sw.js":
            self._file("sw.js", "application/javascript")
        else:
            self._send({"error": "ruta no encontrada"}, 404)

    def do_POST(self):
        ruta = self.path.split("?")[0]
        if not ruta.startswith("/api/registro/"):
            self._send({"error": "ruta no encontrada"}, 404); return
        try:
            largo = int(self.headers.get("Content-Length", 0))
            datos = json.loads(self.rfile.read(largo) or "{}")
        except Exception:
            self._send({"ok": False, "error": "JSON inválido"}); return
        self._send(registrar(ruta.rsplit("/", 1)[-1], datos))

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    global ARGS
    ap = argparse.ArgumentParser(description="NODOS — App de registro")
    ap.add_argument("--host", default="127.0.0.1", help="0.0.0.0 para verlo desde el celular")
    ap.add_argument("--puerto", type=int, default=8081)
    ap.add_argument("--db", default=os.environ.get("NODOS_DB", "nodos"))
    ap.add_argument("--user", default=os.environ.get("NODOS_USER", "postgres"))
    ap.add_argument("--password", default=os.environ.get("NODOS_PASSWORD", ""))
    ap.add_argument("--dbhost", default=os.environ.get("NODOS_HOST", ""))
    ap.add_argument("--dbport", type=int, default=5432)
    ARGS = ap.parse_args()
    srv = ThreadingHTTPServer((ARGS.host, ARGS.puerto), Handler)
    demo = os.environ.get("NODOS_DEMO") == "1"
    print("NODOS Registro (%s) → http://localhost:%d" % ("MODO DEMO" if demo else "base real", ARGS.puerto))
    if ARGS.host == "0.0.0.0":
        print("  Celular (misma red): http://<IP-de-esta-PC>:%d  → Añadir a pantalla de inicio" % ARGS.puerto)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nNODOS: app de registro detenida.")


if __name__ == "__main__":
    main()
