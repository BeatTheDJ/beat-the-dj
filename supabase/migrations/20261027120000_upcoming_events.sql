-- Upcoming event listings for the paused/ended public landing screen.
-- This file is a proposed migration only. It is NOT applied to Supabase by this commit.

create table if not exists public.upcoming_events (
  id uuid primary key default gen_random_uuid(),
  event_date date not null,
  venue text not null check (char_length(btrim(venue)) between 1 and 120),
  event_time text not null check (char_length(btrim(event_time)) between 1 and 80),
  display_order smallint not null unique check (display_order between 1 and 3),
  updated_at timestamptz not null default now()
);

alter table public.upcoming_events enable row level security;

-- Public screens may read event listings; they cannot write them.
grant select on public.upcoming_events to anon, authenticated;
grant insert, update, delete on public.upcoming_events to authenticated;

drop policy if exists "Public can read upcoming events" on public.upcoming_events;
create policy "Public can read upcoming events"
  on public.upcoming_events
  for select
  to anon, authenticated
  using (true);

drop policy if exists "Authorised DJ can insert upcoming events" on public.upcoming_events;
create policy "Authorised DJ can insert upcoming events"
  on public.upcoming_events
  for insert
  to authenticated
  with check (auth.uid() = '48be01ee-0677-4611-943f-0c3c441ee74c'::uuid);

drop policy if exists "Authorised DJ can update upcoming events" on public.upcoming_events;
create policy "Authorised DJ can update upcoming events"
  on public.upcoming_events
  for update
  to authenticated
  using (auth.uid() = '48be01ee-0677-4611-943f-0c3c441ee74c'::uuid)
  with check (auth.uid() = '48be01ee-0677-4611-943f-0c3c441ee74c'::uuid);

drop policy if exists "Authorised DJ can delete upcoming events" on public.upcoming_events;
create policy "Authorised DJ can delete upcoming events"
  on public.upcoming_events
  for delete
  to authenticated
  using (auth.uid() = '48be01ee-0677-4611-943f-0c3c441ee74c'::uuid);

create index if not exists upcoming_events_display_order_idx
  on public.upcoming_events (display_order);

