-- Fridge-to-Table: shopping list aisles, expiry dates, recipe share links
-- Run once in Supabase → SQL Editor (before merging the matching PR).

-- 1) Aisle for each shopping-list item (the app guesses it; you can change it)
alter table public.shopping_list add column if not exists category text;

-- 2) Use-by date for kitchen items
alter table public.pantry_items add column if not exists expires_on date;

-- 3) Shared recipes: a copy of a recipe that anyone with the link can read
create table if not exists public.shared_recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  recipe jsonb not null check (pg_column_size(recipe) < 40000)
);

alter table public.shared_recipes enable row level security;

drop policy if exists "shared recipes insert own" on public.shared_recipes;
create policy "shared recipes insert own" on public.shared_recipes
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "shared recipes read own" on public.shared_recipes;
create policy "shared recipes read own" on public.shared_recipes
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "shared recipes delete own" on public.shared_recipes;
create policy "shared recipes delete own" on public.shared_recipes
  for delete to authenticated using (auth.uid() = user_id);

-- Public read by exact link id only (the table itself can't be listed by others).
create or replace function public.get_shared_recipe(share_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select recipe from public.shared_recipes where id = share_id;
$$;

revoke all on function public.get_shared_recipe(uuid) from public;
grant execute on function public.get_shared_recipe(uuid) to anon, authenticated;

-- 4) "Delete my account" now also removes shared recipes
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'not signed in';
  end if;

  delete from public.pantry_items   where user_id = uid;
  delete from public.saved_recipes  where user_id = uid;
  delete from public.meal_history   where user_id = uid;
  delete from public.meal_plans     where user_id = uid;
  delete from public.shopping_list  where user_id = uid;
  delete from public.guest_menus    where user_id = uid;
  delete from public.feedback       where user_id = uid;
  delete from public.shared_recipes where user_id = uid;
  delete from public.profiles       where user_id = uid;
  delete from auth.users            where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
