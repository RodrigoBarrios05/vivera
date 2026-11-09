-- Vivera: códigos automáticos de producto y catálogo de proveedores.

-- 1. Todos los productos se manejan por pieza.
update public.products set unit = 'pieza' where unit <> 'pieza';
update public.sale_items set unit = 'pieza' where unit <> 'pieza';
update public.purchase_items set unit = 'pieza' where unit <> 'pieza';

-- 2. Generador de códigos cortos y legibles.
create or replace function public.generate_product_code()
returns text
language plpgsql
volatile
set search_path = public, pg_temp
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text := '';
  v_index integer;
begin
  for i in 1..6 loop
    v_index := 1 + floor(random() * length(v_alphabet))::integer;
    v_code := v_code || substr(v_alphabet, v_index, 1);
  end loop;
  return 'VIV-' || v_code;
end;
$$;

revoke all on function public.generate_product_code()
  from public, anon, authenticated;

-- 3. Completar el código de los productos existentes que no tengan uno.
do $$
declare
  v_product record;
  v_code text;
begin
  for v_product in
    select id, organization_id
    from public.products
    where sku is null or trim(sku) = ''
  loop
    loop
      v_code := public.generate_product_code();
      exit when not exists (
        select 1
        from public.products
        where organization_id = v_product.organization_id
          and lower(sku) = lower(v_code)
      );
    end loop;

    update public.products
      set sku = v_code
      where id = v_product.id;
  end loop;
end;
$$;

-- 4. create_product genera el código cuando no se envía uno.
create or replace function public.create_product(
  p_organization_id uuid,
  p_name text,
  p_category_id uuid default null,
  p_sku text default null,
  p_unit text default 'pieza',
  p_sale_price_cents bigint default 0,
  p_cost_cents bigint default 0,
  p_min_stock numeric default 0,
  p_initial_stock numeric default 0,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_product_id uuid;
  v_initial numeric(12,3);
  v_code text;
begin
  if v_user is null then
    raise exception 'Debes iniciar sesión';
  end if;

  if not public.is_org_member(p_organization_id) then
    raise exception 'No tienes acceso a este vivero';
  end if;

  if coalesce(trim(p_name), '') = '' then
    raise exception 'El nombre del producto es obligatorio';
  end if;

  if p_sale_price_cents is null or p_sale_price_cents < 0
     or p_cost_cents is null or p_cost_cents < 0 then
    raise exception 'Los precios no pueden ser negativos';
  end if;

  if p_min_stock is null or p_min_stock < 0 then
    raise exception 'El stock mínimo no puede ser negativo';
  end if;

  if p_initial_stock is null or p_initial_stock < 0 then
    raise exception 'El stock inicial no puede ser negativo';
  end if;

  if p_category_id is not null and not exists (
    select 1 from public.categories
    where id = p_category_id and organization_id = p_organization_id
  ) then
    raise exception 'Categoría inválida';
  end if;

  v_initial := round(p_initial_stock, 3);
  v_code := nullif(trim(p_sku), '');

  if v_code is null then
    loop
      v_code := public.generate_product_code();
      exit when not exists (
        select 1
        from public.products
        where organization_id = p_organization_id
          and lower(sku) = lower(v_code)
      );
    end loop;
  end if;

  insert into public.products (
    organization_id, category_id, name, sku, unit,
    sale_price_cents, cost_cents, stock, min_stock, notes
  )
  values (
    p_organization_id,
    p_category_id,
    trim(p_name),
    v_code,
    'pieza',
    p_sale_price_cents,
    p_cost_cents,
    v_initial,
    round(p_min_stock, 3),
    nullif(trim(p_notes), '')
  )
  returning id into v_product_id;

  if v_initial > 0 then
    insert into public.stock_movements (
      organization_id, product_id, movement_type,
      quantity_delta, stock_after, reason, created_by
    )
    values (
      p_organization_id, v_product_id, 'initial',
      v_initial, v_initial, 'Stock inicial', v_user
    );
  end if;

  return v_product_id;
end;
$$;

-- 5. Catálogo simple de proveedores (solo nombre).
create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index suppliers_org_name_unique
  on public.suppliers (organization_id, lower(name))
  where active;

create index suppliers_org_active_idx
  on public.suppliers (organization_id, active);

alter table public.suppliers enable row level security;

create policy "members can view suppliers"
on public.suppliers for select
to authenticated
using (public.is_org_member(organization_id));

create policy "members can insert suppliers"
on public.suppliers for insert
to authenticated
with check (public.is_org_member(organization_id));

create policy "members can update suppliers"
on public.suppliers for update
to authenticated
using (public.is_org_member(organization_id))
with check (public.is_org_member(organization_id));

revoke all on public.suppliers from anon, authenticated;
grant select on public.suppliers to authenticated;
grant insert (organization_id, name, active)
  on public.suppliers to authenticated;
grant update (name, active)
  on public.suppliers to authenticated;

-- 6. Reutilizar los nombres de proveedores que ya aparecen en compras.
insert into public.suppliers (organization_id, name)
select distinct organization_id, trim(supplier_name)
from public.purchases
where supplier_name is not null
  and trim(supplier_name) <> ''
on conflict do nothing;
