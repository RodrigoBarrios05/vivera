-- Vivera: permisos explícitos. Las escrituras críticas pasan por RPCs.

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

-- Helpers usados por las políticas RLS -------------------------------------

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
