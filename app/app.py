"""
ShopNotes - mini API de démo DevSecOps.

⚠️  VERSION VOLONTAIREMENT VULNÉRABLE - NE JAMAIS DÉPLOYER ⚠️
Chaque faille est numérotée (VULN-x) pour la démo.
"""
import os
import sqlite3
import subprocess

import yaml
from flask import Flask, request, jsonify

app = Flask(__name__)

# VULN-1 : secret codé en dur dans le code source (détecté par Gitleaks + Semgrep)
FLASK_SECRET_KEY = "f9K2LmQ7vR4tZp8Wn3Yb6Hc1Jd5Ge0XaQ8"
PAYMENT_API_TOKEN = "pay_prod_7Hq2Zr9LmX4vT8nB3cW6yK1dF5gJ0sPe"
app.config["SECRET_KEY"] = FLASK_SECRET_KEY

DB_PATH = os.path.join(os.path.dirname(__file__), "shop.db")


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


@app.route("/")
def index():
    return jsonify(service="shopnotes", status="ok")


@app.route("/health")
def health():
    return "ok"


# VULN-2 : injection SQL (concaténation de l'entrée utilisateur)
# Démo : /user?name=' OR '1'='1   > renvoie TOUS les utilisateurs
@app.route("/user")
def get_user():
    name = request.args.get("name", "")
    conn = sqlite3.connect(DB_PATH)
    query = "SELECT id, name, email FROM users WHERE name = '" + name + "'"
    rows = conn.execute(query).fetchall()
    conn.close()
    return jsonify(rows)


# VULN-3 : injection de commande (shell=True + entrée utilisateur)
# Démo : /ping?host=127.0.0.1;id
@app.route("/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    out = subprocess.check_output("ping -c 1 " + host, shell=True)
    return out


# VULN-4 : désérialisation dangereuse (yaml.load sans SafeLoader)
@app.route("/import", methods=["POST"])
def import_config():
    data = yaml.load(request.data, Loader=yaml.Loader)
    return jsonify(imported=str(data))


if __name__ == "__main__":
    init_db()
    # VULN-5 : mode debug activé + écoute sur toutes les interfaces
    app.run(host="0.0.0.0", port=5000, debug=True)
