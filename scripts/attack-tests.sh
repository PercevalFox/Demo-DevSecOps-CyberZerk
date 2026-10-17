#!/usr/bin/env bash
# Tests d'attaque automatisés (DAST "maison") : on attaque l'app qui tourne
# comme le ferait un pentesteur. Si une attaque réussit, le pipeline échoue.
#
# Usage : ./scripts/attack-tests.sh http://localhost:5000
set -u
TARGET="${1:-http://localhost:5000}"
FAIL=0

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

echo "Cible : $TARGET"
echo

# 1. Injection SQL : la requête ne doit renvoyer qu'un utilisateur au maximum
echo "> Attaque 1 - Injection SQL : /user?name=' OR '1'='1"
BODY=$(curl -s -G "$TARGET/user" --data-urlencode "name=' OR '1'='1")
COUNT=$(echo "$BODY" | grep -o '@shop.local' | wc -l)
if [ "$COUNT" -gt 1 ]; then
  red   "VULNÉRABLE : $COUNT comptes utilisateurs exfiltrés"
  echo "$BODY" | tr -d '\n ' | head -c 300; echo
  FAIL=1
else
  green "Protégé"
fi
echo

# 2. Injection de commande : on essaie d'exécuter une commande sur le serveur
echo "> Attaque 2 - Injection de commande : /ping?host=127.0.0.1;id"
BODY=$(curl -s -G "$TARGET/ping" --data-urlencode "host=127.0.0.1;id")
if echo "$BODY" | grep -q "uid="; then
  red   "VULNÉRABLE : commande exécutée sur le serveur -> $(echo "$BODY" | grep -o 'uid=[^ ]*.*' | head -1)"
  FAIL=1
else
  green "Protégé"
fi
echo

# 3. Désérialisation YAML : on essaie de faire exécuter du code Python au serveur
echo "> Attaque 3 - Désérialisation YAML (exécution de code à distance)"
PAYLOAD='!!python/object/apply:subprocess.check_output [["echo", "RCE_REUSSIE"]]'
BODY=$(curl -s -X POST "$TARGET/import" -H "Content-Type: application/x-yaml" --data-binary "$PAYLOAD")
if echo "$BODY" | grep -q "RCE_REUSSIE"; then
  red   "VULNÉRABLE : code arbitraire exécuté via YAML"
  FAIL=1
else
  green "Protégé"
fi
echo

# 4. Mode debug : la console Werkzeug permet d'exécuter du code depuis le navigateur
echo "> Attaque 4 - Console de debug exposée"
if curl -s "$TARGET/console" | grep -qi "werkzeug\|debugger"; then
  red   "VULNÉRABLE : console de debug Werkzeug accessible"
  FAIL=1
else
  green "Protégé"
fi
echo

if [ "$FAIL" -ne 0 ]; then
  red "RÉSULTAT : l'application est exploitable, déploiement BLOQUÉ"
  exit 1
fi
green "RÉSULTAT : aucune attaque n'a abouti"
