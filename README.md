# ClaudeToolbar

Aplicacion nativa para macOS que muestra el uso de Claude en la barra de herramientas del sistema, junto a los iconos de bateria, WiFi y modo de concentracion.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)

## Funcionalidades

- **Icono en el menu bar** con indicador de color (verde / amarillo / rojo segun disponibilidad)
- **Barra de sesion actual** — porcentaje restante del periodo vigente + tiempo hasta restauracion
- **Barra de uso semanal** — porcentaje restante de la semana + tiempo hasta restauracion
- Actualizacion automatica cada 5 minutos
- Refresco manual con Cmd+R
- Configuracion de session key via interfaz grafica

## Requisitos

- macOS 13.0 (Ventura) o superior
- Cuenta de Claude (Free, Pro o Team)
- Swift Command Line Tools (`xcode-select --install`)

## Instalacion

```bash
# Clonar el repositorio
git clone <repo-url>
cd claude-toolbar

# Compilar y crear el app bundle
make bundle

# Instalar en /Applications y abrir
make install
```

## Desarrollo

```bash
# Ejecutar en modo debug (sin app bundle)
swift run

# O con make
make dev
```

## Configuracion inicial

Al abrir la app por primera vez apareceran las instrucciones de configuracion:

1. Abre **claude.ai** en tu navegador con sesion iniciada
2. Abre DevTools con **Cmd+Option+I**
3. Ve a **Application → Storage → Cookies → `https://claude.ai`**
4. Copia el valor de la cookie **`sessionKey`**
5. Pegalo en la app y pulsa "Guardar y conectar"

> La session key se guarda de forma local en UserDefaults. No se envia a ningun servidor externo.

## Arquitectura

```
MenuBarExtra (SwiftUI)
    └── ContentView
        ├── UsageBarView (sesion)
        └── UsageBarView (semanal)

ClaudeAPIService (actor)
    └── URLSession → claude.ai/api/organizations/{id}/usage

UsageViewModel (@MainActor)
    ├── Auto-refresh cada 5 minutos
    └── Publicacion de UsageMetric a la UI
```

## Gitflow

```
main        ← releases de produccion (etiquetados)
develop     ← integracion continua
feature/*   ← nuevas funcionalidades
release/*   ← preparacion de version
hotfix/*    ← correcciones urgentes
```

## Licencia

MIT
