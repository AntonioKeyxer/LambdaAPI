// ─────────────────────────────────────────────────────────────
// parameters.bicepparam — Archivo de parámetros para Bicep
// ─────────────────────────────────────────────────────────────
// Equivalente al parameters.json de CloudFormation, pero con
// sintaxis propia de Bicep (más legible que JSON puro).
//
// USO:
//   az deployment group create \
//     --parameters @parameters.bicepparam
// ─────────────────────────────────────────────────────────────

using './main.bicep'   // Vincula este archivo con la plantilla principal

param environmentName = 'lab'

// ⚠️ CAMBIA ESTO: usa tu nombre real (sin espacios, usa guiones)
param uniqueSuffix = 'tu-nombre'

param sqlAdminLogin = 'sqladmin'

// ⚠️ CAMBIA ESTO: usa una contraseña segura
// Requisitos Azure: mín. 8 chars, mayúsculas, minúsculas, números y símbolos
// Ejemplo válido: MiLab2025!
param sqlAdminPassword = 'CambiameAhora123!'

param databaseName = 'mi-primera-db'
