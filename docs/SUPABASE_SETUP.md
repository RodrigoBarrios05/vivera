# Configurar Supabase

El proyecto de Vivera usa un proyecto dedicado de Supabase Cloud y el esquema `public`.

## Opción A: CLI de Supabase (recomendada)

1. Iniciá sesión en una terminal interactiva:

```powershell
npx supabase login
```

2. Vinculá el proyecto:

```powershell
npx supabase link --project-ref <project-ref>
```

3. Aplicá las migraciones:

```powershell
npx supabase db push
```

Las migraciones se aplican en orden:

1. `supabase/migrations/20261106000100_tables.sql`
2. `supabase/migrations/20261106000200_functions.sql`
3. `supabase/migrations/20261106000300_rls.sql`
4. `supabase/migrations/20261106000400_grants.sql`
5. `supabase/migrations/20261106000500_suppliers_and_product_codes.sql`

## Opción B: aplicar SQL sin contraseña de base de datos

El CLI 3.x puede ejecutar SQL contra el proyecto remoto con el token de acceso, sin `supabase link` ni la contraseña de Postgres:

```powershell
npx --yes supabase db query --remote=<project-ref> --file supabase/setup.sql --output-format text --yes
```

`db query` **no registra** el historial de migraciones. Después de aplicar `setup.sql` en un proyecto vacío, marcá las versiones como aplicadas para que un futuro `db push` no intente recrear los objetos existentes:

```powershell
npx --yes supabase migration repair --status applied 20261106000100 20261106000200 20261106000300 20261106000400 20261106000500 --remote=<project-ref> --output-format text --yes
```

Verificá la instalación y el historial:

```powershell
npx --yes supabase migration list --remote=<project-ref> --output-format text
npx --yes supabase db query --remote=<project-ref> --file supabase/verify.sql --read-only --output-format text
```

Si el CLI detecta variables de agente (OpenCode, CI) y no permite el modo interactivo, agregá `--agent no --output-format text` al comando de login.

## Opción C: SQL Editor del panel

Si no podés iniciar sesión con el CLI, abrí **Supabase → SQL Editor** y ejecutá el contenido de `supabase/setup.sql` (incluye las cinco migraciones en orden). También podés pegar cada archivo de migración por separado, respetando el orden.

Después de aplicar el SQL, verificá en **Table Editor** que existan las tablas `organizations`, `profiles`, `organization_members`, `categories`, `products`, `suppliers`, `sales`, `sale_items`, `purchases`, `purchase_items` y `stock_movements`.

La migración de proveedores también completa el código de los productos existentes y normaliza las unidades a `pieza`. Los proveedores que ya aparecían como texto libre en compras se copian al nuevo catálogo `suppliers`.

## Autenticación

- En **Authentication → Providers → Email**, dejá habilitado el proveedor de correo.
- Para pruebas, desactivá **Confirm email** para que el registro inicie sesión de inmediato.
- Para producción, configurá un servidor SMTP propio y volvé a activar la confirmación de correo.
- No se usan teléfonos ni proveedores sociales en este MVP.

## Claves

La app usa `SUPABASE_URL` y la clave pública (`sb_publishable_...`). No uses la clave `service_role` ni `sb_secret_...` en la aplicación.

## Comprobaciones rápidas

Con la app configurada:

1. Registrate y creá un vivero.
2. Verificá que aparezcan las 8 categorías iniciales.
3. Creá un producto con stock inicial y confirmá que reciba un código `VIV-XXXXXX` y se muestre en piezas.
4. Vendé una unidad y confirmá que el stock baje.
5. Anulá la venta y confirmá que el stock vuelva.
6. Creá un proveedor desde **Compras → Nueva compra → Nuevo** y registrá una compra; verificá que el costo promedio cambie.
7. Con otro usuario, unite usando el código de invitación y comprobá que ambos ven el mismo catálogo.
