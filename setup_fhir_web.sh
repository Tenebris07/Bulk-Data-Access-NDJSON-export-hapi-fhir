#!/bin/bash
set -e

# ======================
# CONFIGURACIÓN
# ======================
PG_USER="hapi_user"
PG_PASS="MiPasswordSeguro"
PG_DB="fhirdb"
PATIENTS_TABLE="patients"
OBS_TABLE="observations"
PG_HOST="localhost"
PG_PORT=5432
FHIR_EXPORT_DIR="./fhir_export"
VENV_DIR="./venv_fhir"

# ======================
# CREAR USUARIO Y DB EN POSTGRES
# ======================
echo "📦 Configurando PostgreSQL..."

sudo -u postgres psql <<EOF
DO
\$do\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${PG_USER}') THEN
      CREATE ROLE ${PG_USER} WITH LOGIN PASSWORD '${PG_PASS}';
   END IF;
END
\$do\$;

CREATE DATABASE ${PG_DB} OWNER ${PG_USER};

\c ${PG_DB}

CREATE TABLE IF NOT EXISTS ${PATIENTS_TABLE} (
  id TEXT PRIMARY KEY,
  resourceType TEXT,
  family TEXT,
  given TEXT,
  birthDate DATE
);

CREATE TABLE IF NOT EXISTS ${OBS_TABLE} (
  id TEXT PRIMARY KEY,
  resourceType TEXT,
  subject TEXT,
  code TEXT,
  value TEXT
);
EOF

echo "✅ PostgreSQL listo."

# ======================
# CONFIGURAR ENTORNO PYTHON
# ======================
echo "📦 Configurando entorno Python..."
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate
pip install --upgrade pip
pip install psycopg2-binary flask

echo "✅ Entorno Python listo."

# ======================
# PROCESAR NDJSON A POSTGRES
# ======================
echo "📂 Procesando NDJSON desde $FHIR_EXPORT_DIR..."
for file in $FHIR_EXPORT_DIR/*.ndjson; do
    echo "Procesando $file..."
    python3 <<PYTHON
import json
import psycopg2
import os

PG_USER="${PG_USER}"
PG_PASS="${PG_PASS}"
PG_DB="${PG_DB}"
PG_HOST="${PG_HOST}"
PG_PORT=${PG_PORT}
FHIR_FILE="${file}"
PATIENTS_TABLE="${PATIENTS_TABLE}"
OBS_TABLE="${OBS_TABLE}"

conn = psycopg2.connect(user=PG_USER, password=PG_PASS, dbname=PG_DB, host=PG_HOST, port=PG_PORT)
cur = conn.cursor()

fname = os.path.basename(FHIR_FILE)
if "Patient" in fname:
    table = PATIENTS_TABLE
    for line in open(FHIR_FILE):
        if not line.strip():
            continue
        data = json.loads(line)
        id = data.get("id")
        resourceType = data.get("resourceType")
        family = data.get("name", [{}])[0].get("family") if data.get("name") else None
        given = data.get("name", [{}])[0].get("given", [None])[0] if data.get("name") else None
        birthDate = data.get("birthDate")
        cur.execute(f"""
            INSERT INTO {table} (id, resourceType, family, given, birthDate)
            VALUES (%s,%s,%s,%s,%s) ON CONFLICT (id) DO NOTHING
        """, (id, resourceType, family, given, birthDate))
elif "Observation" in fname:
    table = OBS_TABLE
    for line in open(FHIR_FILE):
        if not line.strip():
            continue
        data = json.loads(line)
        id = data.get("id")
        resourceType = data.get("resourceType")
        subject = data.get("subject", {}).get("reference") if data.get("subject") else None
        code = data.get("code", {}).get("text") if data.get("code") else None
        value = data.get("valueString") if "valueString" in data else str(data.get("valueQuantity", {}).get("value")) if data.get("valueQuantity") else None
        cur.execute(f"""
            INSERT INTO {table} (id, resourceType, subject, code, value)
            VALUES (%s,%s,%s,%s,%s) ON CONFLICT (id) DO NOTHING
        """, (id, resourceType, subject, code, value))

conn.commit()
cur.close()
conn.close()
PYTHON
done
echo "✅ Archivos cargados en PostgreSQL."

# ======================
# CREAR APP FLASK
# ======================
echo "🌐 Creando app web con Flask..."
cat > fhir_web.py <<EOF
from flask import Flask, render_template_string
import psycopg2

app = Flask(__name__)

PG_USER = "${PG_USER}"
PG_PASS = "${PG_PASS}"
PG_DB   = "${PG_DB}"
PG_HOST = "${PG_HOST}"
PG_PORT = ${PG_PORT}

TEMPLATE = """
<!doctype html>
<title>FHIR Data</title>
<h1>Pacientes</h1>
<table border=1>
<tr><th>ID</th><th>ResourceType</th><th>Family</th><th>Given</th><th>BirthDate</th></tr>
{% for row in patients %}
<tr>
  <td>{{ row[0] }}</td>
  <td>{{ row[1] }}</td>
  <td>{{ row[2] }}</td>
  <td>{{ row[3] }}</td>
  <td>{{ row[4] }}</td>
</tr>
{% endfor %}
</table>

<h1>Observations</h1>
<table border=1>
<tr><th>ID</th><th>ResourceType</th><th>Subject</th><th>Code</th><th>Value</th></tr>
{% for row in obs %}
<tr>
  <td>{{ row[0] }}</td>
  <td>{{ row[1] }}</td>
  <td>{{ row[2] }}</td>
  <td>{{ row[3] }}</td>
  <td>{{ row[4] }}</td>
</tr>
{% endfor %}
</table>
"""

@app.route("/")
def index():
    conn = psycopg2.connect(user=PG_USER, password=PG_PASS, dbname=PG_DB, host=PG_HOST, port=PG_PORT)
    cur = conn.cursor()
    cur.execute("SELECT * FROM patients ORDER BY id LIMIT 100")
    patients = cur.fetchall()
    cur.execute("SELECT * FROM observations ORDER BY id LIMIT 100")
    obs = cur.fetchall()
    cur.close()
    conn.close()
    return render_template_string(TEMPLATE, patients=patients, obs=obs)

if __name__ == "__main__":
    app.run(debug=True)
EOF

echo "✅ Script Flask creado: fhir_web.py"
echo "💻 Para ejecutar la web:"
echo "1️⃣ Activar virtualenv: source $VENV_DIR/bin/activate"
echo "2️⃣ Ejecutar: python3 fhir_web.py"
echo "Abre tu navegador en http://localhost:5000 para ver los datos."
