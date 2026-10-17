#!/usr/bin/env bash
#
#   ./scripts/apply-fixes.sh all       > tout corriger (pipeline vert)
#   ./scripts/apply-fixes.sh secrets   > retire les secrets du code       (job 1)
#   ./scripts/apply-fixes.sh code      > corrige les failles du code      (jobs 2, 6)
#   ./scripts/apply-fixes.sh deps      > dépendances + image Docker       (jobs 3, 4, 5)
#   ./scripts/apply-fixes.sh infra     > corrige le Terraform             (job 4)
#
# Note : "secrets" et "code" touchent le même fichier app.py ; "code" inclut donc aussi le retrait des secrets.
set -euo pipefail
cd "$(dirname "$0")/.."

fix_secrets() {
  echo "→ Secrets : suppression du .env.production et des clés codées en dur"
  git rm -q --cached .env.production 2>/dev/null || true
  rm -f .env.production
  python3 - <<'EOF'
import re, pathlib
p = pathlib.Path("app/app.py"); s = p.read_text()
s = re.sub(r'FLASK_SECRET_KEY = ".*?"', 'FLASK_SECRET_KEY = os.environ.get("SECRET_KEY")', s)
s = re.sub(r'PAYMENT_API_TOKEN = ".*?"', 'PAYMENT_API_TOKEN = os.environ.get("PAYMENT_API_TOKEN")', s)
p.write_text(s)
EOF
}

fix_code()   { echo "→ Code : requêtes paramétrées, pas de shell, safe_load, pas de debug"; rm -f .env.production; git rm -q --cached .env.production 2>/dev/null || true; cp fixes/app/app.py app/app.py; }
# Les nouvelles versions de Flask exigent Python >= 3.9 : dépendances et image vont ensemble
fix_deps()   { echo "→ Dépendances à jour + image alpine récente, non-root, HEALTHCHECK"; cp fixes/app/requirements.txt app/requirements.txt; cp fixes/Dockerfile Dockerfile; }
fix_infra()  { echo "→ Terraform : bucket privé, SSH restreint au VPN"; cp fixes/infra/main.tf infra/main.tf; }

case "${1:-all}" in
  secrets) fix_secrets ;;
  code)    fix_code ;;
  deps)    fix_deps ;;
  infra)   fix_infra ;;
  all)     fix_code; fix_deps; fix_infra ;;
  *) echo "Usage : $0 [all|secrets|code|deps|infra]"; exit 1 ;;
esac

echo
git status --short 2>/dev/null || true
echo
echo "Ensuite : git add -A && git commit -m 'fix(security): ...' && git push"
