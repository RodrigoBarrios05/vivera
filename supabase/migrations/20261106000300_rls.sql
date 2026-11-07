-- Vivera: aislamiento por vivero (organización).

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

-- Categorías ---------------------------------------------------------------

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
