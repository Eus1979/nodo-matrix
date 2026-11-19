#!/usr/bin/env python3
"""
NODOS — Interfaz de monitoreo web (sin dependencias externas).

Requisitos: Python 3 (ya incluido en CachyOS) y psql con la base 'nodos'
cargada (sql/01..05). Solo librería estándar: nada más que instalar.

Uso:
    python3 monitor_nodos.py                # abre http://localhost:8080
    python3 monitor_nodos.py --host 0.0.0.0 # para verlo desde el celular
                                            # (misma red Wi-Fi)

En Android: abre http://IP-DE-TU-PC:8080 en Chrome y usa
"Traducir/Añadir a pantalla de inicio" para instalarlo como app.
"""
import argparse
import json
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

BASE = Path(__file__).resolve().parent
STATIC = BASE / "static"

DB = None
_cache = {"ts": 0.0, "data": None}
_cache_lock = threading.Lock()


def run_psql(sql: str) -> str:
    for cmd in (
        ["psql", "-d", DB, "-tAc", sql, "-v", "ON_ERROR_STOP=1"],
        ["sudo", "-u", "postgres", "psql", "-d", DB, "-tAc", sql, "-v", "ON_ERROR_STOP=1"],
    ):
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        except FileNotFoundError:
            continue
        if r.returncode == 0 and r.stderr.strip() == "":
            return r.stdout.strip()
        last_err = (cmd[0], r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "sin detalle")
    raise RuntimeError(f"{last_err[0]}: {last_err[1]}")


def scalar_json(sql: str):
    out = run_psql(sql)
    return json.loads(out) if out else None


QUERIES = {
    "kpi": """
        SELECT coalesce(json_build_object(
            'nodos',        (SELECT count(*) FROM nodos.nodo WHERE activo),
            'miembros',     (SELECT count(*) FROM nodos.miembro WHERE estado = 'activo'),
            'actividades',  (SELECT count(*) FROM nodos.actividad WHERE estado IN ('planificado','activo')),
            'activos',      (SELECT count(*) FROM nodos.activo_tecnologico WHERE activo),
            'ingresos',     (SELECT coalesce(sum(monto),0) FROM nodos.movimiento_financiero WHERE tipo='ingreso'),
            'egresos',      (SELECT coalesce(sum(monto),0) FROM nodos.movimiento_financiero WHERE tipo='egreso'),
            'movimientos',  (SELECT count(*) FROM nodos.movimiento_financiero),
            'reuniones',    (SELECT count(*) FROM nodos.reunion)
        )::text, '{}') FROM (SELECT 1) _;
    """,
    "nodos": """
        SELECT coalesce(json_agg(t)::text, '[]') FROM (
            SELECT n.codigo, n.nombre, n.etapa,
                   (SELECT count(*) FROM nodos.miembro m
                     WHERE m.nodo_id = n.id AND m.estado = 'activo') AS miembros,
                   (SELECT count(*) FROM nodos.actividad a
                     WHERE a.nodo_id = n.id AND a.estado IN ('planificado','activo')) AS actividades,
                   (SELECT count(*) FROM nodos.activo_tecnologico x
                     WHERE x.nodo_id = n.id AND x.activo) AS activos,
                   coalesce((SELECT sum(monto) FROM nodos.movimiento_financiero f
                              WHERE f.nodo_id = n.id AND f.tipo = 'ingreso'), 0)
                 - coalesce((SELECT sum(monto) FROM nodos.movimiento_financiero f
                              WHERE f.nodo_id = n.id AND f.tipo = 'egreso'), 0) AS saldo
            FROM nodos.nodo n WHERE n.activo ORDER BY n.id
        ) t;
    """,
    "red": """
        SELECT coalesce(json_agg(row_to_json(v))::text, '[]')
        FROM nodos.vw_red_nodos v;
    """,
    "libro": """
        SELECT coalesce(json_agg(t)::text, '[]') FROM (
            SELECT m.id, n.codigo AS nodo, m.tipo, m.monto, m.moneda, m.descripcion,
                   m.fecha::text AS fecha, m.estado, m.soporte_referencia,
                   (SELECT count(*) FROM nodos.verificacion_movimiento v
                     WHERE v.movimiento_id = m.id AND v.resultado) AS verificaciones
            FROM nodos.movimiento_financiero m
            JOIN nodos.nodo n ON n.id = m.nodo_id
            ORDER BY m.id DESC LIMIT 50
        ) t;
    """,
    "alertas": """
        SELECT coalesce(json_agg(t)::text, '[]') FROM (
            SELECT 'transparencia'::text AS tipo, nodo_codigo, alerta AS detalle
              FROM nodos.vw_alerta_transparencia
            UNION ALL
            SELECT 'custodia', nodo_codigo,
                   nombre || ': ' || custodios_actuales || '/' || custodios_minimos || ' custodios'
              FROM nodos.vw_alerta_custodia
            UNION ALL
            SELECT 'continuidad', nodo_codigo, detalle
              FROM nodos.vw_alerta_continuidad
            UNION ALL
            SELECT 'backup', nodo_codigo,
                   nombre || ': ultimo backup ' || coalesce(ultimo_backup::text, 'nunca')
              FROM nodos.vw_backup_vencidos
        ) t;
    """,
    "actividades": """
        SELECT coalesce(json_agg(t)::text, '[]') FROM (
            SELECT a.titulo, a.tipo, a.estado, n.codigo AS nodo,
                   tm.nombres AS titular, sm.nombres AS suplente
            FROM nodos.actividad a
            JOIN nodos.nodo n    ON n.id = a.nodo_id
            JOIN nodos.miembro tm ON tm.id = a.titular_id
            JOIN nodos.miembro sm ON sm.id = a.suplente_id
            ORDER BY a.id
        ) t;
    """,
}


def collect():
    now = time.time()
    with _cache_lock:
        if _cache["data"] and now - _cache["ts"] < 5:
            return _cache["data"]
    data = {"generado": time.strftime("%Y-%m-%d %H:%M:%S")}
    for name, sql in QUERIES.items():
        try:
            data[name] = scalar_json(sql)
        except Exception as e:
            data[name] = None
            data.setdefault("errores", {})[name] = str(e)
    with _cache_lock:
        _cache["ts"] = now
        _cache["data"] = data
    return data


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        ruta = self.path.split("?")[0]
        if ruta == "/api/all":
            self._json(collect())
        elif ruta == "/manifest.webmanifest":
            self._json({
                "name": "NODOS — Monitoreo",
                "short_name": "NODOS",
                "start_url": "/",
                "display": "standalone",
                "background_color": "#0b0f14",
                "theme_color": "#22c55e",
            })
        elif ruta in ("/", "/index.html"):
            try:
                body = (STATIC / "index.html").read_bytes()
            except FileNotFoundError:
                self._text("Falta monitor/static/index.html", 500)
                return
            self._bytes(body, "text/html; charset=utf-8")
        else:
            self._text("Ruta no encontrada", 404)

    def _json(self, obj, code=200):
        self._bytes(json.dumps(obj, ensure_ascii=False).encode("utf-8"),
                    "application/json; charset=utf-8", code)

    def _bytes(self, body, ctype, code=200):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _text(self, msg, code):
        self._bytes(msg.encode("utf-8"), "text/plain; charset=utf-8", code)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    global DB
    ap = argparse.ArgumentParser(description="Monitoreo NODOS")
    ap.add_argument("--host", default="127.0.0.1",
                    help="127.0.0.1 para local; 0.0.0.0 para verlo desde el celular")
    ap.add_argument("--puerto", type=int, default=8080)
    ap.add_argument("--db", default="nodos", help="nombre de la base de datos")
    args = ap.parse_args()
    DB = args.db

    srv = ThreadingHTTPServer((args.host, args.puerto), Handler)
    print(f"NODOS: monitoreo en ejecución → http://{'localhost' if args.host == '127.0.0.1' else args.host}:{args.puerto}")
    if args.host == "0.0.0.0":
        print(f"  Desde el celular (misma red): http://<IP-de-esta-PC>:{args.puerto}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nNODOS: servidor detenido.")


if __name__ == "__main__":
    main()
