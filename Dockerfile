# VULN-7 : image de base ancienne et lourde (centaines de CVE OS)
FROM python:3.7

# VULN-8 : ADD au lieu de COPY, pas d'utilisateur non-root, pas de HEALTHCHECK
ADD app /app
WORKDIR /app
RUN pip install -r requirements.txt

EXPOSE 5000
CMD ["python", "app.py"]
