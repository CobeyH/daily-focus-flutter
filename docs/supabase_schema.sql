-- ============================================================================
-- Daily Focus — Supabase schema
-- Run this in the Supabase Dashboard → SQL Editor, or via the Supabase CLI.
--
-- The three tables mirror the app's local persistence model:
--   * tasks          → AppStorage.loadTasks / saveTasks
--   * entries        → AppStorage.loadEntries / saveEntries (per-day progress)
--   * active_timers  → AppStorage.loadActiveTimers / saveActiveTimers
--
-- Every row is scoped by user_id and guarded by Row-Level Security (RLS), so
-- the anon (publishable) key used in the Flutter app can only read/write the
-- signed-in user's own rows.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Helper: ensure the `updated_at` column reflects the latest write time, used
-- for last-writer-wins merge resolution across devices.
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- tasks
-- ---------------------------------------------------------------------------
create table if not exists public.tasks (
  id          text primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- JSON mirror of Task.toJson() minus the id (kept in a separate column).
  payload     jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

alter table public.tasks enable row level security;

drop policy if exists "tasks_select_own" on public.tasks;
create policy "tasks_select_own"
  on public.tasks for select
  using (auth.uid() = user_id);

drop policy if exists "tasks_insert_own" on public.tasks;
create policy "tasks_insert_own"
  on public.tasks for insert
  with check (auth.uid() = user_id);

drop policy if exists "tasks_update_own" on public.tasks;
create policy "tasks_update_own"
  on public.tasks for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "tasks_delete_own" on public.tasks;
create policy "tasks_delete_own"
  on public.tasks for delete
  using (auth.uid() = user_id);

drop trigger if exists trg_tasks_updated_at on public.tasks;
create trigger trg_tasks_updated_at
  before update on public.tasks
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- entries
-- ---------------------------------------------------------------------------
create table if not exists public.entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  task_id     text not null references public.tasks (id) on delete cascade,
  date_key    text not null,                -- yyyy-MM-dd
  progress    integer not null default 0,
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  -- A task has at most one progress value per day.
  unique (user_id, task_id, date_key)
);

alter table public.entries enable row level security;

drop policy if exists "entries_select_own" on public.entries;
create policy "entries_select_own"
  on public.entries for select
  using (auth.uid() = user_id);

drop policy if exists "entries_insert_own" on public.entries;
create policy "entries_insert_own"
  on public.entries for insert
  with check (auth.uid() = user_id);

drop policy if exists "entries_update_own" on public.entries;
create policy "entries_update_own"
  on public.entries for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "entries_delete_own" on public.entries;
create policy "entries_delete_own"
  on public.entries for delete
  using (auth.uid() = user_id);

drop trigger if exists trg_entries_updated_at on public.entries;
create trigger trg_entries_updated_at
  before update on public.entries
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- active_timers
-- ---------------------------------------------------------------------------
create table if not exists public.active_timers (
  id          text primary key,             -- task_id
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  payload     jsonb not null default '{}'::jsonb,   -- ActiveTimer.toJson()
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  unique (user_id, id)
);

alter table public.active_timers enable row level security;

drop policy if exists "active_timers_select_own" on public.active_timers;
create policy "active_timers_select_own"
  on public.active_timers for select
  using (auth.uid() = user_id);

drop policy if exists "active_timers_insert_own" on public.active_timers;
create policy "active_timers_insert_own"
  on public.active_timers for insert
  with check (auth.uid() = user_id);

drop policy if exists "active_timers_update_own" on public.active_timers;
create policy "active_timers_update_own"
  on public.active_timers for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "active_timers_delete_own" on public.active_timers;
create policy "active_timers_delete_own"
  on public.active_timers for delete
  using (auth.uid() = user_id);

drop trigger if exists trg_active_timers_updated_at on public.active_timers;
create trigger trg_active_timers_updated_at
  before update on public.active_timers
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- sync_state
-- Stores the user's latest baseline per table so the app can do incremental
-- syncs (only fetch rows changed since the last pull) and resolve conflicts
-- deterministically via updated_at.
-- ---------------------------------------------------------------------------
create table if not exists public.sync_state (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  tasks_since timestamptz,
  entries_since timestamptz,
  timers_since timestamptz,
  updated_at  timestamptz not null default now()
);

alter table public.sync_state enable row level security;

drop policy if exists "sync_state_select_own" on public.sync_state;
create policy "sync_state_select_own"
  on public.sync_state for select
  using (auth.uid() = user_id);

drop policy if exists "sync_state_insert_own" on public.sync_state;
create policy "sync_state_insert_own"
  on public.sync_state for insert
  with check (auth.uid() = user_id);

drop policy if exists "sync_state_update_own" on public.sync_state;
create policy "sync_state_update_own"
  on public.sync_state for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);