-- Vivera: esquema inicial
-- Dinero en centavos, cantidades con 3 decimales, historial sin borrados físicos.

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
