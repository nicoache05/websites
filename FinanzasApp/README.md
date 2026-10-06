# Finanzas — app iOS de ingresos y egresos

App nativa para iPhone (SwiftUI + SwiftData, iOS 18 o superior) para registrar ingresos y egresos.

## Funciones

- **Registro de movimientos**: monto, tipo (ingreso/egreso), **fecha y hora del consumo**, **tipo de consumo** (alimentación, transporte, vivienda, servicios, salud, etc.), **método de pago** (efectivo, débito, crédito, transferencia, billetera digital) y nota.
- **Resumen semanal** (lunes a domingo): ganancia o pérdida, ingresos y egresos, gráfica por tipo de consumo y totales por método de pago. Puedes navegar a semanas anteriores.
- **Lista de movimientos** agrupada por día, con búsqueda, filtros por tipo y método de pago, edición y borrado.
- **Recordatorio de fin de semana**: notificación (por defecto el domingo a las 20:00, configurable) con la ganancia o pérdida de la semana, los ingresos y los egresos.
- **Centro de control** (iOS 18): dos controles, «Registrar egreso» y «Registrar ingreso», que abren la app con el formulario listo. También funcionan con Siri, la app Atajos y el botón de Acción.
- **Notion**: cada movimiento se crea, actualiza o envía a la papelera en una base de datos de Notion. Si no hay conexión, queda «pendiente» y se sube después.
- Moneda automática según la región o elegida en Ajustes (MXN, COP, ARS, CLP, PEN, USD, EUR…).

## Estructura

```
FinanzasApp/
├── project.yml                 # Proyecto XcodeGen (genera Finanzas.xcodeproj)
├── Finanzas/                   # App
│   ├── FinanzasApp.swift       # Punto de entrada, notificaciones y atajos de Siri
│   ├── Models/                 # MoneyEntry (SwiftData), categorías, métodos de pago, resumen semanal
│   ├── Services/               # NotionService, sincronización, Llavero, recordatorio semanal
│   └── Views/                  # Resumen, Movimientos, Formulario, Ajustes
├── FinanzasWidgets/            # Extensión con los controles del Centro de control
└── Shared/                     # App Intents compartidos por la app y la extensión
```

## Cómo compilarla e instalarla

Necesitas una Mac con **Xcode 16 o superior**.

1. Instala XcodeGen: `brew install xcodegen`
2. En esta carpeta: `xcodegen generate`
3. Abre `Finanzas.xcodeproj`.
4. En cada target (**Finanzas** y **FinanzasWidgets**) › *Signing & Capabilities*:
   - Elige tu **Team**.
   - Cambia el bundle id `com.tuempresa.finanzas` por uno tuyo (y `…widgets` para la extensión).
   - En **App Groups** usa el mismo grupo en ambos targets (por ejemplo `group.com.tunombre.finanzas`) y actualiza `AppGroup.identifier` en `Shared/QuickAction.swift`.
5. Conecta tu iPhone y pulsa ▶︎.

Para distribuirla en la App Store o por TestFlight necesitas una cuenta del Apple Developer Program: *Product › Archive* y súbela desde el Organizer.

## Conectar Notion

1. Entra a <https://www.notion.so/my-integrations>, crea una integración **interna** y copia el token (`ntn_…`).
2. Crea en Notion una base de datos en blanco (vista de tabla).
3. En la base de datos: **··· › Conexiones** y agrega tu integración.
4. Copia el enlace de la base de datos (**··· › Copiar enlace**).
5. En la app: **Ajustes › Notion**, pega el token y el enlace, y toca **Conectar**.

La app crea sola las columnas que falten:

| Columna         | Tipo en Notion | Contenido                                |
|-----------------|----------------|------------------------------------------|
| *(título)*      | Título         | Nota o, si no hay, el tipo de consumo    |
| Monto           | Número         | Monto positivo                           |
| Neto            | Número         | + para ingresos, − para egresos          |
| Tipo            | Selección      | Ingreso / Egreso                         |
| Fecha           | Fecha          | Fecha del consumo                        |
| Categoría       | Selección      | Tipo de consumo                          |
| Método de pago  | Selección      | Efectivo, tarjeta, transferencia…        |
| Nota            | Texto          | Nota libre                               |

Consejo: en Notion agrupa la tabla por semana de «Fecha» y muestra la suma de «Neto» para ver la ganancia o pérdida semanal también allí.

El token se guarda en el Llavero del iPhone. La sincronización es del iPhone hacia Notion: los cambios hechos directamente en Notion no vuelven a la app.

## Añadir los controles al Centro de control

1. Abre el Centro de control (desliza desde la esquina superior derecha).
2. Toca **+** arriba a la izquierda › **Agregar un control**.
3. Busca **Finanzas** y elige **Registrar egreso** y/o **Registrar ingreso**.

## Cómo funciona el recordatorio semanal

iOS no deja ejecutar código justo antes de mostrar una notificación local, así que la app programa las próximas 8 semanas con los totales ya calculados y las reprograma cada vez que agregas, editas o borras un movimiento, o cambias el día y la hora. Así el aviso del domingo siempre trae las cifras de esa semana.

## Integración continua

`.github/workflows/finanzas-ios.yml` genera el proyecto y lo compila para el simulador en un runner macOS cada vez que cambia algo en `FinanzasApp/`.
