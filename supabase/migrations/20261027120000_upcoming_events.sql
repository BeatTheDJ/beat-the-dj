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


-- Replace the complete listing in one transaction, restricted to the authorised DJ.
create or replace function public.replace_upcoming_events(p_events jsonb)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is distinct from '48be01ee-0677-4611-943f-0c3c441ee74c'::uuid then
    raise exception 'Not authorised to manage upcoming events';
  end if;

  if p_events is null or jsonb_typeof(p_events) <> 'array' or jsonb_array_length(p_events) > 3 then
    raise exception 'Provide zero to three upcoming events';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_events) as e(event_date date, venue text, event_time text, display_order smallint)
    where e.event_date is null
       or e.venue is null or char_length(btrim(e.venue)) not between 1 and 120
       or e.event_time is null or char_length(btrim(e.event_time)) not between 1 and 80
       or e.display_order is null or e.display_order not between 1 and 3
  ) then
    raise exception 'Each event needs a valid date, venue, time and display order';
  end if;

  if (select count(distinct e.display_order) from jsonb_to_recordset(p_events) as e(display_order smallint))
     <> jsonb_array_length(p_events) then
    raise exception 'Event display orders must be unique';
  end if;

  delete from public.upcoming_events;

  insert into public.upcoming_events(event_date, venue, event_time, display_order)
  select e.event_date, btrim(e.venue), btrim(e.event_time), e.display_order
  from jsonb_to_recordset(p_events) as e(event_date date, venue text, event_time text, display_order smallint)
  order by e.display_order;
end;
$$;

revoke all on function public.replace_upcoming_events(jsonb) from public, anon;
grant execute on function public.replace_upcoming_events(jsonb) to authenticated;
