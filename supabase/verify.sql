-- Vivera: verificación rápida de la instalación del esquema.
-- Ejecutar en el SQL Editor después de aplicar supabase/setup.sql.

-- 1. Tablas esperadas (deben aparecer 11).
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_type = 'BASE TABLE'
order by table_name;

-- 2. Funciones y RPCs esperados (deben aparecer 16).
select routine_name
from information_schema.routines
where routine_schema = 'public'
order by routine_name;

-- 3. RLS habilitado en todas las tablas.
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
order by c.relname;

-- 4. Cantidad de políticas por tabla.
select tablename, count(*) as policies
from pg_policies
where schemaname = 'public'
group by tablename
order by tablename;

-- 5. Trigger de creación de perfiles sobre auth.users.
select tgname
from pg_trigger
where tgrelid = 'auth.users'::regclass
  and not tgisinternal;

-- 6. Permisos de las tablas para el rol authenticated.
select table_name, string_agg(privilege_type, ', ' order by privilege_type) as privileges
from information_schema.role_table_grants
where table_schema = 'public'
  and grantee = 'authenticated'
group by table_name
order by table_name;

-- 7. Códigos automáticos y unidades normalizadas.
select count(*) as productos_sin_codigo
from public.products
where sku is null or trim(sku) = '';

select unit, count(*) as productos
from public.products
group by unit
order by unit;

-- 8. Proveedores disponibles (incluye los nombres usados en compras).
select count(*) as proveedores
from public.suppliers;
