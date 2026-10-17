# ShopNotes - démo DevSecOps pour CyberZerk

Une mini-API Flask **volontairement vulnérable** et un pipeline GitHub Actions qui détecte et bloque automatiquement ses failles, à chaque push et chaque Pull Request.

> ⚠️ Ne jamais déployer la version de `main` : elle contient des failles réelles et exploitables.

## Le pipeline (`.github/workflows/devsecops.yml`)

| # | Contrôle | Outil | Ce qu'il attrape dans ce projet |
|---|----------|-------|---------------------------------|
| 1 | Secrets | Gitleaks | Clés codées en dur dans `app.py`, `.env.production` commité |
| 2 | SAST | Bandit | Injection SQL, injection de commande, `yaml.load`, `debug=True` |
| 3 | SCA | pip-audit | ~80 CVE dans Flask 0.12, Jinja2 2.10, PyYAML 5.3, requests 2.19… |
| 4 | IaC | Checkov | Dockerfile root sans HEALTHCHECK, bucket S3 public, SSH ouvert au monde |
| 5 | Image | Trivy | Image `python:3.7` en fin de vie, CVE critiques OS + Python |
| 6 | DAST | script d'attaque + OWASP ZAP | Exploitation réelle de l'app lancée dans le pipeline |
| 7 | Security Gate | — | Tableau de synthèse, bloque si un contrôle échoue |

Les résultats de Gitleaks, Bandit, Checkov et Trivy sont aussi publiés dans
l'onglet **Security -> Code scanning** (repo public, ou privé avec GitHub Advanced Security).

## Corriger

```bash
./scripts/apply-fixes.sh all        # tout corriger
./scripts/apply-fixes.sh secrets    # ou étape par étape : secrets | code | deps | infra
```

Les versions corrigées sont dans `fixes/`, chaque correctif `FIX-x` répond à une faille `VULN-x`.

## Lancer en local (optionnel, Docker requis)

```bash
docker build -t shopnotes . && docker run -d -p 5000:5000 --name shopnotes shopnotes
./scripts/attack-tests.sh http://localhost:5000
docker rm -f shopnotes
```
