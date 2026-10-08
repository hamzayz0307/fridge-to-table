-- Fridge-to-Table: feedback table + "delete my account"
-- Run once in Supabase → SQL Editor.

-- 1) Feedback from inside the app
create table if not exists public.feedback (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  kind text not null default 'other' check (kind in ('bug', 'idea', 'other')),
  message text not null check (char_length(message) between 1 and 2000),
  page text,
  language text,
  user_agent text
);

alter table public.feedback enable row level security;

drop policy if exists "feedback insert own" on public.feedback;
create policy "feedback insert own" on public.feedback
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "feedback read own" on public.feedback;
create policy "feedback read own" on public.feedback
  for select to authenticated using (auth.uid() = user_id);

-- 2) Let a signed-in user delete their own account and all their data
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
  delete from public.profiles       where user_id = uid;
  delete from auth.users            where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
