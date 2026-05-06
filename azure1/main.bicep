// ─────────────────────────────────────────────────────────────
// LAB AZURE-01 — SQL Server + SQL Database con Bicep
// ─────────────────────────────────────────────────────────────
// Bicep es el lenguaje IaC nativo de Azure. Es más legible que
// los ARM Templates (JSON) y se compila a ARM antes de desplegarse.
// ─────────────────────────────────────────────────────────────

// ── PARÁMETROS ───────────────────────────────────────────────
// En Bicep los parámetros van al inicio del archivo, sin sección
// especial. Se declaran con la palabra clave "param".

// @description agrega documentación visible en el portal de Azure
@description('Prefijo del entorno. Ej: lab, dev, prod')
param environmentName string = 'lab'

@description('Tu nombre o alias único, sin espacios (ej: juan-perez)')
param uniqueSuffix string

@description('Región de Azure donde se crearán los recursos')
param location string = resourceGroup().location  
// resourceGroup().location toma la región del Resource Group automáticamente

@description('Nombre del administrador del SQL Server')
param sqlAdminLogin string = 'sqladmin'

// @secure() indica que este valor es sensible:
// - No se muestra en logs ni en outputs
// - Azure lo almacena cifrado
// - Bicep exige que NO tenga valor por defecto (por seguridad)
@secure()
@description('Contraseña del administrador (mínimo 8 chars, mayúsculas, números y símbolos)')
param sqlAdminPassword string

@description('Nombre de la base de datos a crear')
param databaseName string = 'mi-primera-db'


// ── VARIABLES ────────────────────────────────────────────────
// Las variables son valores calculados internamente.
// No son editables por el usuario al desplegar.

// El nombre del SQL Server debe ser globalmente único en Azure
// (como un bucket S3). Usamos uniqueString() para garantizarlo.
// uniqueString() genera un hash determinista de 13 chars basado
// en el ID del Resource Group.
var sqlServerName = '${environmentName}-sqlsrv-${uniqueSuffix}-${uniqueString(resourceGroup().id)}'

var tags = {
  environment: environmentName
  createdBy: uniqueSuffix
  project: 'lab-bicep-azure'
}


// ── RECURSO 1: AZURE SQL SERVER ──────────────────────────────
// El servidor lógico que "contiene" las bases de datos.
// En Azure SQL, el servidor no es una VM; es un endpoint administrado.
//
// Sintaxis Bicep:  resource <nombreLocal> '<tipo>@<versión>' = { ... }
//   nombreLocal  → alias interno para referenciar este recurso más abajo
//   tipo         → proveedor/recurso de Azure (como el Type en CloudFormation)
//   versión      → versión de la API ARM que se usará
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags

  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword

    // publicNetworkAccess: permite conexiones desde internet.
    // En producción usarías 'Disabled' y accederías por Private Endpoint.
    publicNetworkAccess: 'Enabled'

    minimalTlsVersion: '1.2'  // Versión mínima de TLS permitida
  }
}


// ── REGLA DE FIREWALL (sub-recurso del servidor) ─────────────
// Sin esta regla, nadie puede conectarse al servidor, ni siquiera tú.
// "AllowAllAzureIps" es un rango especial que permite todos los IPs
// de servicios Azure (0.0.0.0 → 0.0.0.0).
//
// Para producción: especifica IPs concretos en lugar de 0.0.0.0.
resource firewallRule 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  // La dependencia se establece con "parent": Bicep sabe que esta
  // regla pertenece al sqlServer de arriba y lo crea después.
  parent: sqlServer
  name: 'AllowAllAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}


// ── RECURSO 2: AZURE SQL DATABASE ───────────────────────────
// La base de datos real que vivirá dentro del servidor lógico.
//
// SKU (Stock Keeping Unit): define el tier de rendimiento y precio.
// Usamos "Basic" (el más económico, ideal para labs):
//   - 5 DTUs (Database Transaction Units)
//   - 2 GB de almacenamiento máximo
//   - ~$5 USD/mes
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer        // ← Bicep infiere la dependencia automáticamente
  name: databaseName
  location: location
  tags: tags

  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5            // 5 DTUs
  }

  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'   // Juego de caracteres (estándar)
    maxSizeBytes: 2147483648                     // 2 GB en bytes
    requestedBackupStorageRedundancy: 'Local'    // Backups locales (más económico)
  }
}


// ── OUTPUTS ──────────────────────────────────────────────────
// Valores que Bicep exporta al terminar el despliegue.
// Equivalente a la sección Outputs en CloudFormation.

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
// FQDN ejemplo: lab-sqlsrv-juan-perez-abc123.database.windows.net

output sqlServerName string = sqlServer.name

output databaseName string = sqlDatabase.name

output connectionStringTemplate string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${databaseName};User ID=${sqlAdminLogin};Password=<TU_PASSWORD>;Encrypt=True;'
