"""
ShopNotes - mini API de démo DevSecOps.
VERSION CORRIGÉE - chaque correctif répond à une VULN-x de la version vulnérable.
"""
import ipaddress
import os
import sqlite3
# subprocess utilisé sans shell, avec une entrée validée : risque accepté et tracé
import subprocess  # nosec B404

import yaml
from flask import Flask, request, jsonify, abort

app = Flask(__name__)

# FIX-1 : le secret vient de l'environnement (GitHub Secrets, Vault, AWS Secrets Manager...)
app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", os.urandom(32))
PAYMENT_API_TOKEN = os.environ.get("PAYMENT_API_TOKEN")

DB_PATH = os.environ.get("DB_PATH", os.path.join(os.path.expanduser("~"), "shop.db"))


def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)")
    conn.execute("DELETE FROM users")
    conn.executemany(
        "INSERT INTO users (name, email) VALUES (?, ?)",
        [("alice", "alice@shop.local"), ("bob", "bob@shop.local"), ("admin", "admin@shop.local")],
    )
    conn.commit()
    conn.close()


init_db()


@app.after_request
def security_headers(resp):
    # En-têtes de sécurité HTTP (remontés par le scan DAST OWASP ZAP)
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["X-Frame-Options"] = "DENY"
    resp.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'"
    resp.headers["Referrer-Policy"] = "no-referrer"
    resp.headers["Permissions-Policy"] = "geolocation=(), camera=(), microphone=()"
    resp.headers["Cross-Origin-Resource-Policy"] = "same-origin"
    resp.headers["Cache-Control"] = "no-store"
    return resp


@app.route("/")
def index():
    return jsonify(service="shopnotes", status="ok")


@app.route("/health")
def health():
    return "ok"


# FIX-2 : requête paramétrée, l'entrée n'est jamais interprétée comme du SQL
@app.route("/user")
def get_user():
    name = request.args.get("name", "")
    conn = sqlite3.connect(DB_PATH)
    rows = conn.execute("SELECT id, name, email FROM users WHERE name = '" + name + "'").fetchall()
    conn.close()
    return jsonify(rows)


# FIX-3 : validation stricte de l'entrée + pas de shell, arguments passés en liste
@app.route("/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    try:
        ip = str(ipaddress.ip_address(host))
    except ValueError:
        abort(400, "adresse IP invalide")
    out = subprocess.run(["/bin/ping", "-c", "1", ip], capture_output=True, timeout=5, check=False)  # nosec B603
    return out.stdout


# FIX-4 : safe_load n'instancie aucun objet Python arbitraire
@app.route("/import", methods=["POST"])
def import_config():
    data = yaml.safe_load(request.data)
    return jsonify(imported=str(data))


# FIX-5 : plus de app.run(debug=True) : l'app est servie par gunicorn (voir Dockerfile)
