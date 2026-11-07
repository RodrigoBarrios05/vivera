-- Vivera: esquema completo para aplicar desde el SQL Editor de Supabase.
-- Generado a partir de supabase/migrations/*.sql en orden.

-- ===========================================================================
-- 20261106000100_tables.sql
-- ===========================================================================
-- Vivera: esquema inicial
-- Dinero en centavos, cantidades con 3 decimales, historial sin borrados fÃ­sicos.

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 120),
  currency_code text not null default 'MXN' check (currency_code ~ '^[A-Z]{3}$'),
  locale text not null default 'es_MX',
  timezone text not null default 'America/Mexico_City',
  invite_code text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id),
  unique (user_id)
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index categories_org_name_unique
  on public.categories (organization_id, lower(name))
  where active;

create table public.products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null check (char_length(name) between 1 and 160),
  sku text,
  unit text not null default 'pieza' check (char_length(unit) between 1 and 30),
  sale_price_cents bigint not null default 0 check (sale_price_cents >= 0),
  cost_cents bigint not null default 0 check (cost_cents >= 0),
  stock numeric(12,3) not null default 0 check (stock >= 0),
  min_stock numeric(12,3) not null default 0 check (min_stock >= 0),
  notes text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index products_org_active_idx on public.products (organization_id, active);
create index products_org_name_idx on public.products (organization_id, lower(name));
create unique index products_org_sku_unique
  on public.products (organization_id, lower(sku))
  where sku is not null;

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  sale_number bigint generated always as identity unique,
  total_cents bigint not null default 0 check (total_cents >= 0),
  payment_method text not null check (payment_method in ('efectivo', 'transferencia', 'tarjeta', 'otro')),
  notes text,
  status text not null default 'completed' check (status in ('completed', 'cancelled')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by uuid references public.profiles(id) on delete set null,
  cancel_reason text
);

create index sales_org_created_idx on public.sales (organization_id, created_at desc);
create index sales_org_status_idx on public.sales (organization_id, status);

create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  product_name text not null,
  unit text not null,
  quantity numeric(12,3) not null check (quantity > 0),
  unit_price_cents bigint not null check (unit_price_cents >= 0),
  subtotal_cents bigint not null check (subtotal_cents >= 0)
);

create index sale_items_sale_idx on public.sale_items (sale_id);

create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  purchase_number bigint generated always as identity unique,
  supplier_name text,
  total_cents bigint not null default 0 check (total_cents >= 0),
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index purchases_org_created_idx on public.purchases (organization_id, created_at desc);

create table public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  product_name text not null,
  unit text not null,
  quantity numeric(12,3) not null check (quantity > 0),
  unit_cost_cents bigint not null check (unit_cost_cents >= 0),
  subtotal_cents bigint not null check (subtotal_cents >= 0)
);

create index purchase_items_purchase_idx on public.purchase_items (purchase_id);

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  movement_type text not null check (movement_type in ('initial', 'purchase', 'sale', 'adjustment', 'sale_cancel')),
  quantity_delta numeric(12,3) not null,
  stock_after numeric(12,3) not null check (stock_after >= 0),
  reference_id uuid,
  reason text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index stock_movements_org_created_idx on public.stock_movements (organization_id, created_at desc);
create index stock_movements_product_idx on public.stock_movements (product_id, created_at desc);


-- ===========================================================================
-- 20261106000200_functions.sql
-- ===========================================================================
-- Vivera: funciones auxiliares, triggers y RPCs transaccionales.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger organizations_set_updated_at
before update on public.organizations
for each row execute function public.set_updated_at();

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger products_set_updated_at
before update on public.products
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, nullif(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Perfiles para usuarios que ya existieran antes de aplicar este esquema.
insert into public.profiles (id, full_name)
select
  u.id,
  nullif(u.raw_user_meta_data ->> 'full_name', '')
from auth.users u
on conflict (id) do nothing;

create or replace function public.is_org_member(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.organization_members m
    where m.organization_id = p_organization_id
      and m.user_id = auth.uid()
  );
$$;

create or replace function public.current_org_id()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select m.organization_id
  from public.organization_members m
  where m.user_id = auth.uid()
  limit 1;
$$;

create or replace function public.shares_org_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.organization_members mine
    join public.organization_members theirs
      on theirs.organization_id = mine.organization_id
    where mine.user_id = auth.uid()
      and theirs.user_id = p_user_id
  );
$$;

create or replace function public.generate_invite_code()
returns text
language plpgsql
set search_path = public, pg_temp
as $$
declare
  v_code text;
begin
  loop
    v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
    exit when not exists (
      select 1 from public.organizations where invite_code = v_code
    );
  end loop;
  return v_code;
end;
$$;

create or replace function public.create_organization(
  p_name text,
  p_currency_code text default 'MXN',
  p_locale text default 'es_MX',
  p_timezone text default 'America/Mexico_City'
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_org_id uuid;
  v_currency text;
  v_locale text;
  v_timezone text;
  v_code text;
begin
  if v_user is null then
    raise exception 'Debes iniciar sesiÃ³n';
  end if;

  if exists (
    select 1 from public.organization_members where user_id = v_user
  ) then
    raise exception 'Ya perteneces a un vivero';
  end if;

  if coalesce(trim(p_name), '') = '' then
    raise exception 'El nombre del vivero es obligatorio';
  end if;

  v_currency := upper(coalesce(nullif(trim(p_currency_code), ''), 'MXN'));
  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'La moneda debe tener tres letras';
  end if;

  v_locale := coalesce(nullif(trim(p_locale), ''), 'es_MX');
  v_timezone := coalesce(nullif(trim(p_timezone), ''), 'America/Mexico_City');
  v_code := public.generate_invite_code();

  insert into public.organizations (name, currency_code, locale, timezone, invite_code)
  values (trim(p_name), v_currency, v_locale, v_timezone, v_code)
  returning id into v_org_id;

  insert into public.organization_members (organization_id, user_id, role)
  values (v_org_id, v_user, 'owner');

  insert into public.categories (organization_id, name, sort_order)
  values
    (v_org_id, 'Plantas', 1),
    (v_org_id, 'Ãrboles', 2),
    (v_org_id, 'Arbustos', 3),
    (v_org_id, 'Flores', 4),
    (v_org_id, 'Macetas', 5),
    (v_org_id, 'Sustratos', 6),
    (v_org_id, 'Insumos', 7),
    (v_org_id, 'Otros', 8);

  return v_org_id;
end;
$$;

create or replace function public.join_organization(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_org public.organizations%rowtype;
begin
  if v_user is null then
    raise exception 'Debes iniciar sesiÃ³n';
  end if;

  if coalesce(trim(p_code), '') = '' then
    raise exception 'Ingresa un cÃ³digo de invitaciÃ³n';
  end if;

  select * into v_org
  from public.organizations
  where invite_code = upper(trim(p_code));

  if not found then
    raise exception 'CÃ³digo de invitaciÃ³n invÃ¡lido';
  end if;

  if exists (
    select 1 from public.organization_members
    where user_id = v_user and organization_id = v_org.id
  ) then
    return v_org.id;
  end if;

  if exists (
    select 1 from public.organization_members where user_id = v_user
  ) then
    raise exception 'Ya perteneces a un vivero';
  end if;

  insert into public.organization_members (organization_id, user_id, role)
  values (v_org.id, v_user, 'member');

  return v_org.id;
end;
$$;

create or replace function public.rotate_invite_code(p_organization_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_code text;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesiÃ³n';
  end if;

  if not exists (
    select 1
    from public.organization_members
    where organization_id = p_organization_id
      and user_id = auth.uid()
      and role = 'owner'
  ) then
    raise exception 'Solo el dueÃ±o puede cambiar el cÃ³digo';
  end if;

  v_code := public.generate_invite_code();
  update public.organizations
    set invite_code = v_code
    where id = p_organization_id;

  if not found then
    raise exception 'Vivero no encontrado';
  end if;

  return v_code;
end;
$$;

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
begin
  if v_user is null then
    raise exception 'Debes iniciar sesiÃ³n';
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
    raise exception 'El stock mÃ­nimo no puede ser negativo';
  end if;

  if p_initial_stock is null or p_initial_stock < 0 then
    raise exception 'El stock inicial no puede ser negativo';
  end if;

  if p_category_id is not null and not exists (
    select 1 from public.categories
    where id = p_category_id and organization_id = p_organization_id
  ) then
    raise exception 'CategorÃ­a invÃ¡lida';
  end if;

  v_initial := round(p_initial_stock, 3);

  insert into public.products (
    organization_id, category_id, name, sku, unit,
    sale_price_cents, cost_cents, stock, min_stock, notes
  )
  values (
    p_organization_id,
    p_category_id,
    trim(p_name),
    nullif(trim(p_sku), ''),
    coalesce(nullif(trim(p_unit), ''), 'pieza'),
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

create or replace function public.create_sale(
  p_organization_id uuid,
  p_items jsonb,
  p_payment_method text,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_sale_id uuid;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty numeric(12,3);
  v_subtotal bigint;
  v_total bigint := 0;
  v_stock_after numeric(12,3);
begin
  if v_user is null then
    raise exception 'Debes iniciar sesiÃ³n';
  end if;

  if not public.is_org_member(p_organization_id) then
    raise exception 'No tienes acceso a este vivero';
  end if;

  if p_payment_method not in ('efectivo', 'transferencia', 'tarjeta', 'otro') then
    raise exception 'MÃ©todo de pago invÃ¡lido';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Los productos de la venta son invÃ¡lidos';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'La venta debe tener al menos un producto';
  end if;

  insert into public.sales (organization_id, payment_method, notes, created_by)
  values (p_organization_id, p_payment_method, nullif(trim(p_notes), ''), v_user)
  returning id into v_sale_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    if jsonb_typeof(v_item) <> 'object'
       or not (v_item ? 'product_id')
       or not (v_item ? 'quantity') then
      raise exception 'Producto de venta invÃ¡lido';
    end if;

    v_qty := round((v_item ->> 'quantity')::numeric, 3);
    if v_qty is null or v_qty <= 0 then
      raise exception 'Cantidad invÃ¡lida';
    end if;

    select * into v_product
    from public.products
    where id = (v_item ->> 'product_id')::uuid
      and organization_id = p_organization_id
      and active = true
    for update;

    if not found then
      raise exception 'Producto no encontrado o inactivo';
    end if;

    if v_product.stock < v_qty then
      raise exception 'Stock insuficiente de % (disponible: %)', v_product.name, v_product.stock;
    end if;

    v_stock_after := v_product.stock - v_qty;
    v_subtotal := round(v_product.sale_price_cents * v_qty)::bigint;

    insert into public.sale_items (
      sale_id, product_id, product_name, unit,
      quantity, unit_price_cents, subtotal_cents
    )
    values (
      v_sale_id, v_product.id, v_product.name, v_product.unit,
      v_qty, v_product.sale_price_cents, v_subtotal
    );

    update public.products
      set stock = v_stock_after
      where id = v_product.id;

    insert into public.stock_movements (
      organization_id, product_id, movement_type,
      quantity_delta, stock_after, reference_id, created_by
    )
    values (
      p_organization_id, v_product.id, 'sale',
      -v_qty, v_stock_after, v_sale_id, v_user
    );

    v_total := v_total + v_subtotal;
  end loop;

  update public.sales set total_cents = v_total where id = v_sale_id;
  return v_sale_id;
end;
$$;

create or replace function public.create_purchase(
  p_organization_id uuid,
  p_items jsonb,
  p_supplier_name text default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_purchase_id uuid;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty numeric(12,3);
  v_unit_cost bigint;
  v_subtotal bigint;
  v_total bigint := 0;
  v_new_stock numeric(12,3);
  v_new_cost bigint;
begin
  if v_user is null then
    raise exception 'Debes iniciar sesiÃ³n';
  end if;

  if not public.is_org_member(p_organization_id) then
    raise exception 'No tienes acceso a este vivero';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Los productos de la compra son invÃ¡lidos';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'La compra debe tener al menos un producto';
  end if;

  insert into public.purchases (organization_id, supplier_name, notes, created_by)
  values (p_organization_id, nullif(trim(p_supplier_name), ''), nullif(trim(p_notes), ''), v_user)
  returning id into v_purchase_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    if jsonb_typeof(v_item) <> 'object'
       or not (v_item ? 'product_id')
       or not (v_item ? 'quantity')
       or not (v_item ? 'unit_cost_cents') then
      raise exception 'Producto de compra invÃ¡lido';
    end if;

    v_qty := round((v_item ->> 'quantity')::numeric, 3);
    v_unit_cost := (v_item ->> 'unit_cost_cents')::bigint;

    if v_qty is null or v_qty <= 0 then
      raise exception 'Cantidad invÃ¡lida';
    end if;

    if v_unit_cost is null or v_unit_cost < 0 then
      raise exception 'Costo invÃ¡lido';
    end if;

    select * into v_product
    from public.products
    where id = (v_item ->> 'product_id')::uuid
      and organization_id = p_organization_id
      and active = true
    for update;

    if not found then
      raise exception 'Producto no encontrado o inactivo';
    end if;

    v_new_stock := v_product.stock + v_qty;
    if v_new_stock > 0 then
      v_new_cost := round(
        (v_product.stock * v_product.cost_cents + v_qty * v_unit_cost) / v_new_stock
      )::bigint;
    else
      v_new_cost := v_unit_cost;
    end if;

    v_subtotal := round(v_unit_cost * v_qty)::bigint;

    insert into public.purchase_items (
      purchase_id, product_id, product_name, unit,
      quantity, unit_cost_cents, subtotal_cents
    )
    values (
      v_purchase_id, v_product.id, v_product.name, v_product.unit,
      v_qty, v_unit_cost, v_subtotal
    );

    update public.products
      set stock = v_new_stock,
          cost_cents = v_new_cost
      where id = v_product.id;

    insert into public.stock_movements (
      organization_id, product_id, movement_type,
      quantity_delta, stock_after, reference_id, created_by
    )
    values (
      p_organization_id, v_product.id, 'purchase',
      v_qty, v_new_stock, v_purchase_id, v_user
    );

    v_total := v_total + v_subtotal;
  end loop;

  update public.purchases set total_cents = v_total where id = v_purchase_id;
  return v_purchase_id;
end;
$$;

create or replace function public.adjust_stock(
  p_organization_id uuid,
  p_product_id uuid,
  p_new_stock numeric,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_product public.products%rowtype;
  v_new_stock numeric(12,3);
  v_delta numeric(12,3);
begin
  if v_user is null then
    raise exception 'Debes iniciar sesiÃ³n';
  end if;

  if not public.is_org_member(p_organization_id) then
    raise exception 'No tienes acceso a este vivero';
  end if;

  if p_new_stock is null or p_new_stock < 0 then
    raise exception 'El stock no puede ser negativo';
  end if;

  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Indica el motivo del ajuste';
  end if;

  v_new_stock := round(p_new_stock, 3);

  select * into v_product
  from public.products
  where id = p_product_id
    and organization_id = p_organization_id
  for update;

  if not found then
    raise exception 'Producto no encontrado';
  end if;

  v_delta := v_new_stock - v_product.stock;

  if v_delta = 0 then
    return;
  end if;

  update public.products
    set stock = v_new_stock
    where id = p_product_id;

  insert into public.stock_movements (
    organization_id, product_id, movement_type,
    quantity_delta, stock_after, reason, created_by
  )
  values (
    p_organization_id, p_product_id, 'adjustment',
    v_delta, v_new_stock, trim(p_reason), v_user
  );
end;
$$;

create or replace function public.cancel_sale(
  p_organization_id uuid,
  p_sale_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_sale public.sales%rowtype;
  v_item public.sale_items%rowtype;
  v_stock_after numeric(12,3);
begin
  if v_user is null then
    raise exception 'Debes iniciar sesiÃ³n';
  end if;

  if not public.is_org_member(p_organization_id) then
    raise exception 'No tienes acceso a este vivero';
  end if;

  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Indica el motivo de la anulaciÃ³n';
  end if;

  select * into v_sale
  from public.sales
  where id = p_sale_id
    and organization_id = p_organization_id
  for update;

  if not found then
    raise exception 'Venta no encontrada';
  end if;

  if v_sale.status <> 'completed' then
    raise exception 'La venta ya estÃ¡ anulada';
  end if;

  for v_item in
    select * from public.sale_items where sale_id = p_sale_id
  loop
    perform 1
    from public.products
    where id = v_item.product_id
    for update;

    if not found then
      raise exception 'Producto no encontrado';
    end if;

    update public.products
      set stock = stock + v_item.quantity
      where id = v_item.product_id
      returning stock into v_stock_after;

    insert into public.stock_movements (
      organization_id, product_id, movement_type,
      quantity_delta, stock_after, reference_id, reason, created_by
    )
    values (
      p_organization_id, v_item.product_id, 'sale_cancel',
      v_item.quantity, v_stock_after, p_sale_id, trim(p_reason), v_user
    );
  end loop;

  update public.sales
    set status = 'cancelled',
        cancelled_at = now(),
        cancelled_by = v_user,
        cancel_reason = trim(p_reason)
    where id = p_sale_id;
end;
$$;

create or replace function public.dashboard_summary(
  p_organization_id uuid,
  p_start timestamptz,
  p_end timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesiÃ³n';
  end if;

  if not public.is_org_member(p_organization_id) then
    raise exception 'No tienes acceso a este vivero';
  end if;

  if p_start is null or p_end is null or p_start >= p_end then
    raise exception 'Rango de fechas invÃ¡lido';
  end if;

  select jsonb_build_object(
    'today_sales_cents', coalesce((
      select sum(total_cents)::bigint
      from public.sales
      where organization_id = p_organization_id
        and status = 'completed'
        and created_at >= p_start
        and created_at < p_end
    ), 0),
    'today_sales_count', (
      select count(*)
      from public.sales
      where organization_id = p_organization_id
        and status = 'completed'
        and created_at >= p_start
        and created_at < p_end
    ),
    'inventory_value_cents', coalesce((
      select sum(round(stock * cost_cents))::bigint
      from public.products
      where organization_id = p_organization_id
        and active = true
    ), 0),
    'low_stock_count', (
      select count(*)
      from public.products
      where organization_id = p_organization_id
        and active = true
        and stock <= min_stock
    ),
    'low_stock', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'stock', p.stock,
          'min_stock', p.min_stock,
          'unit', p.unit
        )
        order by p.stock asc, p.name asc
      )
      from (
        select id, name, stock, min_stock, unit
        from public.products
        where organization_id = p_organization_id
          and active = true
          and stock <= min_stock
        order by stock asc, name asc
        limit 5
      ) p
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;


-- ===========================================================================
-- 20261106000300_rls.sql
-- ===========================================================================
-- Vivera: aislamiento por vivero (organizaciÃ³n).

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.organization_members enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.purchases enable row level security;
alter table public.purchase_items enable row level security;
alter table public.stock_movements enable row level security;

-- Organizaciones -----------------------------------------------------------

create policy "members can view their organization"
on public.organizations for select
to authenticated
using (public.is_org_member(id));

create policy "owners can update their organization"
on public.organizations for update
to authenticated
using (
  exists (
    select 1
    from public.organization_members m
    where m.organization_id = organizations.id
      and m.user_id = auth.uid()
      and m.role = 'owner'
  )
)
with check (
  exists (
    select 1
    from public.organization_members m
    where m.organization_id = organizations.id
      and m.user_id = auth.uid()
      and m.role = 'owner'
  )
);

-- Perfiles -----------------------------------------------------------------

create policy "members can view profiles in their organization"
on public.profiles for select
to authenticated
using (id = auth.uid() or public.shares_org_with(id));

create policy "users can update their own profile"
on public.profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- Miembros -----------------------------------------------------------------

create policy "members can view members of their organization"
on public.organization_members for select
to authenticated
using (public.is_org_member(organization_id));

-- CategorÃ­as ---------------------------------------------------------------

create policy "members can view categories"
on public.categories for select
to authenticated
using (public.is_org_member(organization_id));

create policy "members can insert categories"
on public.categories for insert
to authenticated
with check (public.is_org_member(organization_id));

create policy "members can update categories"
on public.categories for update
to authenticated
using (public.is_org_member(organization_id))
with check (public.is_org_member(organization_id));

-- Productos ----------------------------------------------------------------

create policy "members can view products"
on public.products for select
to authenticated
using (public.is_org_member(organization_id));

create policy "members can insert products"
on public.products for insert
to authenticated
with check (
  public.is_org_member(organization_id)
  and stock = 0
);

create policy "members can update products"
on public.products for update
to authenticated
using (public.is_org_member(organization_id))
with check (public.is_org_member(organization_id));

-- Ventas -------------------------------------------------------------------

create policy "members can view sales"
on public.sales for select
to authenticated
using (public.is_org_member(organization_id));

create policy "members can view sale items"
on public.sale_items for select
to authenticated
using (
  exists (
    select 1
    from public.sales s
    where s.id = sale_items.sale_id
      and public.is_org_member(s.organization_id)
  )
);

-- Compras ------------------------------------------------------------------

create policy "members can view purchases"
on public.purchases for select
to authenticated
using (public.is_org_member(organization_id));

create policy "members can view purchase items"
on public.purchase_items for select
to authenticated
using (
  exists (
    select 1
    from public.purchases p
    where p.id = purchase_items.purchase_id
      and public.is_org_member(p.organization_id)
  )
);

-- Movimientos de stock -----------------------------------------------------

create policy "members can view stock movements"
on public.stock_movements for select
to authenticated
using (public.is_org_member(organization_id));


-- ===========================================================================
-- 20261106000400_grants.sql
-- ===========================================================================
-- Vivera: permisos explÃ­citos. Las escrituras crÃ­ticas pasan por RPCs.

revoke all on public.organizations from anon, authenticated;
grant select on public.organizations to authenticated;
grant update (name, currency_code, locale, timezone)
  on public.organizations to authenticated;

revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

revoke all on public.organization_members from anon, authenticated;
grant select on public.organization_members to authenticated;

revoke all on public.categories from anon, authenticated;
grant select on public.categories to authenticated;
grant insert (organization_id, name, sort_order, active)
  on public.categories to authenticated;
grant update (name, sort_order, active)
  on public.categories to authenticated;

revoke all on public.products from anon, authenticated;
grant select on public.products to authenticated;
grant insert (
  organization_id, category_id, name, sku, unit,
  sale_price_cents, cost_cents, min_stock, notes, active
) on public.products to authenticated;
grant update (
  category_id, name, sku, unit,
  sale_price_cents, cost_cents, min_stock, notes, active
) on public.products to authenticated;

revoke all on public.sales from anon, authenticated;
grant select on public.sales to authenticated;

revoke all on public.sale_items from anon, authenticated;
grant select on public.sale_items to authenticated;

revoke all on public.purchases from anon, authenticated;
grant select on public.purchases to authenticated;

revoke all on public.purchase_items from anon, authenticated;
grant select on public.purchase_items to authenticated;

revoke all on public.stock_movements from anon, authenticated;
grant select on public.stock_movements to authenticated;

-- Funciones internas -------------------------------------------------------

revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.generate_invite_code() from public, anon, authenticated;

-- Helpers usados por las polÃ­ticas RLS -------------------------------------

revoke all on function public.is_org_member(uuid) from public, anon, authenticated;
grant execute on function public.is_org_member(uuid) to authenticated;

revoke all on function public.current_org_id() from public, anon, authenticated;
grant execute on function public.current_org_id() to authenticated;

revoke all on function public.shares_org_with(uuid) from public, anon, authenticated;
grant execute on function public.shares_org_with(uuid) to authenticated;

-- RPCs de negocio ----------------------------------------------------------

revoke all on function public.create_organization(text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.create_organization(text, text, text, text)
  to authenticated;

revoke all on function public.join_organization(text)
  from public, anon, authenticated;
grant execute on function public.join_organization(text) to authenticated;

revoke all on function public.rotate_invite_code(uuid)
  from public, anon, authenticated;
grant execute on function public.rotate_invite_code(uuid) to authenticated;

revoke all on function public.create_product(uuid, text, uuid, text, text, bigint, bigint, numeric, numeric, text)
  from public, anon, authenticated;
grant execute on function public.create_product(uuid, text, uuid, text, text, bigint, bigint, numeric, numeric, text)
  to authenticated;

revoke all on function public.create_sale(uuid, jsonb, text, text)
  from public, anon, authenticated;
grant execute on function public.create_sale(uuid, jsonb, text, text)
  to authenticated;

revoke all on function public.create_purchase(uuid, jsonb, text, text)
  from public, anon, authenticated;
grant execute on function public.create_purchase(uuid, jsonb, text, text)
  to authenticated;

revoke all on function public.adjust_stock(uuid, uuid, numeric, text)
  from public, anon, authenticated;
grant execute on function public.adjust_stock(uuid, uuid, numeric, text)
  to authenticated;

revoke all on function public.cancel_sale(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.cancel_sale(uuid, uuid, text)
  to authenticated;

revoke all on function public.dashboard_summary(uuid, timestamptz, timestamptz)
  from public, anon, authenticated;
grant execute on function public.dashboard_summary(uuid, timestamptz, timestamptz)
  to authenticated;
