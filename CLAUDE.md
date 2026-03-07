# ClaudeToolbar

## Descripcion del Proyecto

Aplicacion nativa para macOS que muestra el uso de sesion de Claude en tiempo real directamente en la barra de herramientas del sistema (menu bar), junto al icono de bateria, WiFi y modo de concentracion.

### Funcionalidades
- **Barra de sesion actual**: porcentaje de uso del periodo de sesion vigente con tiempo de restauracion
- **Barra semanal**: porcentaje de uso semanal con fecha/hora de restauracion
- Actualizacion automatica cada 5 minutos
- Indicador de color en el menu bar (verde/amarillo/rojo segun disponibilidad)
- Configuracion de session key via interfaz grafica
- Boton de refresco manual

---

## Stack Tecnologico

- **Lenguaje**: Swift 6 (strict concurrency)
- **UI**: SwiftUI + `MenuBarExtra` (macOS 13+)
- **Arquitectura**: MVVM
- **Networking**: `URLSession` async/await
- **Concurrencia**: `actor` para servicios, `@MainActor` para ViewModels
- **Persistencia**: `UserDefaults` para session key
- **Build**: Swift Package Manager (SPM)
- **Target minimo**: macOS 13.0 (Ventura)

---

## Estructura del Proyecto

```
claude-toolbar/
├── CLAUDE.md
├── README.md
├── .gitignore
├── Package.swift
├── Makefile
└── Sources/
    └── ClaudeToolbar/
        ├── ClaudeToolbarApp.swift       # @main entry point + MenuBarExtra
        ├── Models/
        │   └── UsageModels.swift        # Structs de datos (Sendable)
        ├── Services/
        │   └── ClaudeAPIService.swift   # Actor de networking con claude.ai
        ├── ViewModels/
        │   └── UsageViewModel.swift     # @MainActor ObservableObject
        └── Views/
            ├── ContentView.swift        # Vista principal del popover
            ├── UsageBarView.swift       # Componente barra de progreso
            └── SettingsView.swift       # Configuracion de session key
```

---

## Arquitectura

### Flujo de datos
```
claude.ai API → ClaudeAPIService (actor) → UsageViewModel (@MainActor) → SwiftUI Views
```

### Autenticacion
La app usa la `sessionKey` cookie del navegador del usuario para autenticarse con la API interna de claude.ai. El usuario debe copiarla desde las DevTools del navegador.

**Endpoints utilizados:**
1. `GET https://claude.ai/api/organizations` — obtener el ID de la organizacion
2. `GET https://claude.ai/api/organizations/{id}/usage` — datos de uso actual

### Modelos de datos

- `UsageMetric`: unidad de medicion (usado, limite, fecha de reset)
- `ClaudeUsageData`: contenedor con sesion + semanal
- `UsageResponse`: decodificacion de la respuesta JSON de la API

---

## Workflow de Desarrollo: Gitflow

```
main        ← produccion (releases etiquetados)
develop     ← integracion continua
feature/*   ← nuevas funcionalidades (branch desde develop)
release/*   ← preparacion de release (branch desde develop)
hotfix/*    ← correcciones urgentes (branch desde main)
```

**Convenciones de commits:**
```
feat: nueva funcionalidad
fix: correccion de bug
chore: tarea de mantenimiento
docs: documentacion
refactor: refactorizacion sin cambio de comportamiento
test: tests
```

---

## Como Compilar y Ejecutar

### Requisitos
- macOS 13.0+
- Swift 6.x (Command Line Tools o Xcode)

### Desarrollo
```bash
swift build
swift run
```

### Produccion (app bundle)
```bash
make build       # compila en release
make bundle      # crea ClaudeToolbar.app
make install     # copia a /Applications
```

---

## Configuracion Inicial de la App

1. Abrir `claude.ai` en el navegador (sesion iniciada)
2. Abrir DevTools → Application → Storage → Cookies → `https://claude.ai`
3. Copiar el valor de la cookie `sessionKey`
4. Abrir ClaudeToolbar desde el menu bar → icono engranaje
5. Pegar la session key y guardar

La app actualiza los datos cada 5 minutos automaticamente.

---

## Variables de Configuracion (UserDefaults)

| Clave | Tipo | Descripcion |
|-------|------|-------------|
| `sessionKey` | String | Cookie de autenticacion de claude.ai |

---

## Notas de Implementacion

- La app usa `MenuBarExtra` con `.window` style de SwiftUI (macOS 13+)
- No requiere sandbox para funcionar (acceso de red sin entitlements especiales)
- El icono en el menu bar cambia de color segun el uso: verde (>50%), amarillo (20-50%), rojo (<20%)
- Los datos se cachean en memoria; no se persisten entre reinicios de la app
