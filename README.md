Bulk-Data-Access-NDJSON-export-hapi-fhir

Implementación de Bulk Data Access en HAPI FHIR, con soporte para exportación de datos en formato NDJSON mediante la operación $export.

🚀 Instalación y ejecución
1. Clonar el repositorio oficial de HAPI FHIR
git clone https://github.com/hapifhir/hapi-fhir-jpaserver-starter.git
cd hapi-fhir-jpaserver-starter

2. Instalar Maven manualmente (si no está instalado o hay errores de versión)
cd /opt
sudo wget https://dlcdn.apache.org/maven/maven-3/3.9.11/binaries/apache-maven-3.9.11-bin.tar.gz
sudo tar -xzf apache-maven-3.9.11-bin.tar.gz
sudo mv apache-maven-3.9.11 maven


Crear archivo de perfil:

sudo nano /etc/profile.d/maven.sh


Agregar:

export M2_HOME=/opt/maven
export PATH=$M2_HOME/bin:$PATH


Aplicar cambios:

source /etc/profile.d/maven.sh
mvn -v

⚙️ Configuración
1. Base de datos PostgreSQL

Ingresar a PostgreSQL:

sudo -u postgres psql


Crear la base de datos y el usuario:

CREATE DATABASE hapi_fhir;
CREATE USER hapi_user WITH ENCRYPTED PASSWORD 'MiPasswordSeguro';
GRANT ALL PRIVILEGES ON DATABASE hapi_fhir TO hapi_user;
\q

2. Configuración en pom.xml y application.yaml

Debes modificar:

pom.xml → agregar dependencias de PostgreSQL y deshabilitar H2 en memoria.

application.yaml → configurar datasource para PostgreSQL (host, puerto, usuario, contraseña).

▶️ Ejecutar el servidor

Compilar e iniciar:

mvn clean install -U
mvn spring-boot:run


Acceder al servidor:

http://localhost:8080/fhir/


Probar metadata:

http://localhost:8080/fhir/metadata

📤 Bulk Data Export

Ejecutar la operación $export:

curl -v -X GET \
  -H "Accept: application/fhir+json" \
  -H "Prefer: respond-async" \
  "http://localhost:8080/fhir/\$export"

🧪 Inserción de datos de prueba
Crear un paciente:
curl -X POST "http://localhost:8080/fhir/Patient" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Patient",
    "name": [{
      "family": "Perez",
      "given": ["Carlos"]
    }],
    "gender": "male",
    "birthDate": "1990-01-01"
  }'

Crear observaciones:

Presión arterial:

curl -X POST "http://localhost:8080/fhir/Observation" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Observation",
    "status": "final",
    "category": [{
      "coding": [{
        "system": "http://terminology.hl7.org/CodeSystem/observation-category",
        "code": "vital-signs"
      }]
    }],
    "code": {
      "coding": [{
        "system": "http://loinc.org",
        "code": "85354-9",
        "display": "Blood pressure panel"
      }]
    },
    "subject": {
      "reference": "Patient/1"
    },
    "valueQuantity": {
      "value": 120,
      "unit": "mmHg",
      "system": "http://unitsofmeasure.org",
      "code": "mm[Hg]"
    }
  }'


Peso:

curl -X POST "http://localhost:8080/fhir/Observation" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Observation",
    "status": "final",
    "category": [{
      "coding": [{
        "system": "http://terminology.hl7.org/CodeSystem/observation-category",
        "code": "vital-signs"
      }]
    }],
    "code": {
      "coding": [{
        "system": "http://loinc.org",
        "code": "29463-7",
        "display": "Body Weight"
      }]
    },
    "subject": {
      "reference": "Patient/1"
    },
    "valueQuantity": {
      "value": 70,
      "unit": "kg",
      "system": "http://unitsofmeasure.org",
      "code": "kg"
    }
  }'


Altura:

curl -X POST "http://localhost:8080/fhir/Observation" \
  -H "Content-Type: application/fhir+json" \
  -d '{
    "resourceType": "Observation",
    "status": "final",
    "category": [{
      "coding": [{
        "system": "http://terminology.hl7.org/CodeSystem/observation-category",
        "code": "vital-signs"
      }]
    }],
    "code": {
      "coding": [{
        "system": "http://loinc.org",
        "code": "8302-2",
        "display": "Body Height"
      }]
    },
    "subject": {
      "reference": "Patient/1"
    },
    "valueQuantity": {
      "value": 175,
      "unit": "cm",
      "system": "http://unitsofmeasure.org",
      "code": "cm"
    }
  }'

🔧 Scripts útiles

Dar permisos de ejecución (solo una vez):

chmod +x fhir_bulk_export.sh
chmod +x setup_fhir_web.sh


Ejecutar:

./fhir_bulk_export.sh
./setup_fhir_web.sh
