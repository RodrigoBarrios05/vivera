# Vivera

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Postgres-3ECF8E?logo=supabase&logoColor=white)
![Android](https://img.shields.io/badge/Android-API%2036-3DDC84?logo=android&logoColor=white)

Aplicación móvil para administrar el vivero familiar: catálogo, stock, compras, ventas y un panel general.

- **Plataforma:** Android (Flutter)
- **Backend:** Supabase Cloud (Postgres + Auth + RLS)
- **Idioma:** español (México)
- **Moneda:** MXN (`es_MX`)
- **Zona horaria:** `America/Mexico_City`
- **Sin CFDI ni facturación fiscal**

## Características

- Autenticación con correo y contraseña, más un código de invitación de 8 caracteres por vivero.
- Catálogo con categorías, búsqueda por nombre o código, códigos automáticos `VIV-XXXXXX` y control de stock mínimo.
- Ventas con carrito, cobro, historial y anulación con reposición automática de stock.
- Compras con proveedores reutilizables, actualización de stock y costo promedio ponderado.
- Dashboard con ventas del día, valor del inventario y alertas de stock bajo.
- Aislamiento por organización con RLS y operaciones críticas ejecutadas mediante RPCs transaccionales.

## Estado

La app está implementada en modo **online-first**: las operaciones requieren internet y los datos se sincronizan entre dispositivos a través de Supabase. Las escrituras offline quedan fuera del MVP.

Verificada contra Supabase Cloud y un emulador Android 17 (API 37): autenticación, dashboard, catálogo, ventas, anulación, compras, ajustes, historial y acceso de un segundo miembro al mismo vivero.

## Requisitos

- Flutter 3.47 o superior (Dart 3.13)
- Android SDK 36
- Proyecto de Supabase con Auth por correo y contraseña

## Configuración

1. Copiá `env.example.json` a `env.json` y completá los datos del proyecto:

```json
{
  "SUPABASE_URL": "https://TU-PROYECTO.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

`env.json` está en `.gitignore` y no se sube al repositorio. Usá únicamente la clave pública (`sb_publishable_...` o la `anon` clásica), nunca la `service_role`.

2. Aplicá el esquema de base de datos. Ver [`docs/SUPABASE_SETUP.md`](docs/SUPABASE_SETUP.md).

3. En Supabase, para pruebas, desactivá **Authentication → Providers → Email → Confirm email** (o confirmá manualmente cada correo). Para uso familiar real conviene configurar un proveedor SMTP propio.

## Seguridad y datos privados

- `env.json` guarda la URL y la clave pública del proyecto; está en `.gitignore` y nunca se commitea. `env.example.json` es la plantilla pública.
- No se incluyen credenciales, correos de prueba, códigos de invitación activos, keystores, rutas locales del SDK ni artefactos de compilación.
- La app usa únicamente la clave pública; las escrituras sensibles pasan por RPCs con RLS por organización.

## Ejecutar

```powershell
flutter pub get
flutter run --dart-define-from-file=env.json
```

## Compilar APK

```powershell
flutter build apk --release --dart-define-from-file=env.json
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

## Flujo de uso

1. Crear una cuenta con correo y contraseña.
2. Crear el vivero (el primer usuario queda como dueño) o unirse con un código de invitación de 8 caracteres.
3. Cargar productos en el catálogo con precio de venta, costo, stock mínimo y stock inicial. Cada producto recibe un código automático (`VIV-XXXXXX`) y se maneja por pieza.
4. Registrar compras para aumentar stock; se elige un proveedor ya creado (o se crea uno nuevo con solo su nombre) y el costo promedio ponderado se recalcula solo.
5. Vender desde la pestaña **Vender**; el stock se descuenta de forma atómica.
6. Ajustar stock con un motivo cuando haya diferencias de conteo.
7. Anular ventas si fue necesario; el stock vuelve automáticamente.
8. Compartir el código de invitación desde **Más** para sumar a la familia.

## Stack técnico

- **Flutter + Dart** con Material 3 y navegación nativa.
- **Riverpod** para estado y dependencias.
- **Supabase** (Postgres, Auth, RLS y RPCs transaccionales).
- **intl** para formato de moneda y cantidades en `es_MX`.

## Arquitectura

```
lib/
  core/                  configuración, tema, formateadores, widgets compartidos
  features/
    auth/                login, registro, recuperación de contraseña
    organization/        creación/unión al vivero, código de invitación
    session/             sesión, perfil y membresía activos
    catalog/             productos, categorías, stock y movimientos
    sales/               carrito, cobro, historial y anulación
    purchases/           compras, proveedores y actualización de costo/stock
    dashboard/           resumen del día, inventario y stock bajo
    settings/            cuenta, vivero y administración
    shell/               navegación principal
```

La lógica crítica vive en funciones de Postgres (`supabase/migrations/20261106000200_functions.sql`): creación de vivero, unión por código, ventas, compras, ajustes, anulación y resumen del dashboard. Las tablas tienen RLS por organización y los clientes solo pueden leer; las escrituras sensibles pasan por RPCs.

### Reglas de negocio principales

- Dinero guardado en **centavos** (enteros) para evitar errores de punto flotante.
- Todos los productos se manejan por **pieza**; las cantidades se guardan con 3 decimales (`numeric(12,3)`).
- El código del producto se genera en Postgres (`VIV-` + 6 caracteres) y es único por vivero.
- Los proveedores son un catálogo por vivero; la compra guarda el nombre como instantánea.
- Los ítems de venta/compra guardan nombre y precio del producto al momento del movimiento.
- Una venta no puede dejar stock negativo y se registra en una sola transacción.
- Cada organización tiene un código de invitación único; solo el dueño puede rotarlo.
- Un usuario pertenece a un solo vivero en este MVP.

## Pruebas

```powershell
flutter analyze
flutter test
```

Prueba de humo del backend (crea datos en el vivero de prueba y se puede repetir):

```powershell
$env:VIVERA_OWNER_EMAIL = 'dueno@ejemplo.com'
$env:VIVERA_OWNER_PASSWORD = '...'
$env:VIVERA_SECOND_EMAIL = 'miembro@ejemplo.com'
$env:VIVERA_SECOND_PASSWORD = '...'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke_test.ps1
```

Requiere `env.json` y dos cuentas ya registradas y confirmadas. Las credenciales se leen de variables de entorno o de los parámetros del script; no se guardan en el repositorio.

## Limitaciones del MVP

- Sin fotos de productos, códigos de barras ni lector.
- Sin clientes como entidad; los proveedores solo guardan su nombre.
- Sin facturación, impuestos ni CFDI.
- Sin operaciones offline ni resolución de conflictos.
- Sin roles avanzados: dueño y miembro.
