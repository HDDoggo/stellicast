-- Stellicast initial schema
-- Generated from the application's own types (types/content.ts, types/accounts.ts)
-- and the column names its queries select.
--
-- Apply once in Supabase: Dashboard -> SQL Editor -> New query -> paste -> Run.
-- Safe to re-run: every statement is idempotent.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- users (public profile rows, one per auth.users record)
-- ---------------------------------------------------------------------------
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  display_name text,
  avatar_url text,
  banner_url text,
  bio text,
  website text,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- channels
-- ---------------------------------------------------------------------------
create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  channel_type text not null default 'creator' check (channel_type in ('creator','studio')),
  display_name text not null,
  handle text not null unique,
  description text,
  avatar_url text,
  banner_url text,
  video_count integer not null default 0,
  follower_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- videos
-- ---------------------------------------------------------------------------
create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text,
  video_url text not null default '',
  thumbnail_url text,
  duration numeric not null default 0,
  views bigint not null default 0,
  likes integer not null default 0,
  dislikes integer not null default 0,
  stars integer not null default 0,
  comment_count integer not null default 0,
  visibility text not null default 'public' check (visibility in ('public','unlisted','private')),
  tags text[] not null default '{}',
  is_ai boolean not null default false,
  is_promotional boolean not null default false,
  channel_id uuid references public.channels(id) on delete cascade,
  uploader_id uuid references public.users(id) on delete set null,
  user_id uuid references public.users(id) on delete set null,
  status text not null default 'ready',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists videos_channel_idx on public.videos(channel_id);
create index if not exists videos_created_idx on public.videos(created_at desc);

-- ---------------------------------------------------------------------------
-- comments
-- ---------------------------------------------------------------------------
create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  message text not null,
  parent_comment_id uuid references public.comments(id) on delete cascade,
  like_count integer not null default 0,
  dislike_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create index if not exists comments_video_idx on public.comments(video_id, created_at desc);

-- ---------------------------------------------------------------------------
-- engagement tables
-- ---------------------------------------------------------------------------
create table if not exists public.comment_likes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

create table if not exists public.comment_dislikes (
  comment_id uuid not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

create table if not exists public.video_likes (
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, user_id)
);

create table if not exists public.video_dislikes (
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, user_id)
);

create table if not exists public.video_stars (
  video_id uuid not null references public.videos(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (video_id, user_id)
);

-- ---------------------------------------------------------------------------
-- followers
-- ---------------------------------------------------------------------------
create table if not exists public.followers (
  channel_id uuid not null references public.channels(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  notify text not null default 'none' check (notify in ('none','trending','all')),
  following_since timestamptz not null default now(),
  primary key (channel_id, user_id)
);

-- ---------------------------------------------------------------------------
-- sectors
-- ---------------------------------------------------------------------------
create table if not exists public.sectors (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null unique,
  description text,
  icon text,
  member_count integer not null default 0,
  video_count integer not null default 0,
  star_map boolean not null default true,
  private_access boolean not null default false,
  open_posting boolean not null default true,
  approval_for_posting boolean not null default false,
  allow_ai boolean not null default true,
  min_video_length numeric not null default 0,
  max_video_length numeric not null default 3600,
  rules text[] not null default '{}',
  owner_id uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sector_members (
  sector_id uuid not null references public.sectors(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  roles text[] not null default '{member}',
  permissions text[] not null default '{}',
  joined_at timestamptz not null default now(),
  primary key (sector_id, user_id)
);

create table if not exists public.sector_videos (
  video_id uuid not null references public.videos(id) on delete cascade,
  sector_id uuid not null references public.sectors(id) on delete cascade,
  approval_status text not null default 'approved' check (approval_status in ('approved','pending','rejected')),
  submitted_at timestamptz not null default now(),
  primary key (video_id, sector_id)
);

create table if not exists public.sector_bans (
  id uuid primary key default gen_random_uuid(),
  sector_id uuid not null references public.sectors(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  banned_by_id uuid references public.users(id) on delete set null,
  ban_reason text,
  banned_until timestamptz,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- channel applications (early access)
-- ---------------------------------------------------------------------------
create table if not exists public.channel_early_access_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  channel_name text,
  channel_type text default 'creator',
  description text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewer_note text,
  reviewed_at timestamptz,
  reviewed_by uuid references public.users(id) on delete set null,
  submitted_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- studio / creator channel extras
-- ---------------------------------------------------------------------------
create table if not exists public.creators (
  channel_id uuid primary key references public.channels(id) on delete cascade,
  website text,
  social_links text[] not null default '{}'
);

create table if not exists public.studios (
  channel_id uuid primary key references public.channels(id) on delete cascade,
  company_name text,
  verified boolean not null default false,
  team_size integer not null default 1,
  team uuid[] not null default '{}',
  business_email text
);

-- ---------------------------------------------------------------------------
-- username history
-- ---------------------------------------------------------------------------
create table if not exists public.username_change_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  old_username text,
  new_username text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- rate limiting (server-side only; no anon policies)
-- ---------------------------------------------------------------------------
create table if not exists public.engagement_rate_limits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  action text not null,
  last_action_at timestamptz not null default now()
);

create table if not exists public.view_rate_limits (
  id uuid primary key default gen_random_uuid(),
  video_id uuid references public.videos(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  last_action_at timestamptz not null default now()
);

create table if not exists public.comment_engagement_rate_limits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  action text not null,
  last_action_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['users','channels','videos','sectors'] loop
    execute format('drop trigger if exists %I_touch on public.%I', t, t);
    execute format('create trigger %I_touch before update on public.%I for each row execute function public.touch_updated_at()', t, t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- row level security
-- ---------------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.channels enable row level security;
alter table public.videos enable row level security;
alter table public.comments enable row level security;
alter table public.comment_likes enable row level security;
alter table public.comment_dislikes enable row level security;
alter table public.video_likes enable row level security;
alter table public.video_dislikes enable row level security;
alter table public.video_stars enable row level security;
alter table public.followers enable row level security;
alter table public.sectors enable row level security;
alter table public.sector_members enable row level security;
alter table public.sector_videos enable row level security;
alter table public.sector_bans enable row level security;
alter table public.channel_early_access_applications enable row level security;
alter table public.creators enable row level security;
alter table public.studios enable row level security;
alter table public.username_change_history enable row level security;
alter table public.engagement_rate_limits enable row level security;
alter table public.view_rate_limits enable row level security;
alter table public.comment_engagement_rate_limits enable row level security;

-- Public read where it makes sense
drop policy if exists "public read users" on public.users;
create policy "public read users" on public.users for select using (true);

drop policy if exists "public read channels" on public.channels;
create policy "public read channels" on public.channels for select using (true);

drop policy if exists "public read videos" on public.videos;
create policy "public read videos" on public.videos for select using (true);

drop policy if exists "public read comments" on public.comments;
create policy "public read comments" on public.comments for select using (true);

drop policy if exists "public read sectors" on public.sectors;
create policy "public read sectors" on public.sectors for select using (true);

drop policy if exists "public read sector members" on public.sector_members;
create policy "public read sector members" on public.sector_members for select using (true);

drop policy if exists "public read sector videos" on public.sector_videos;
create policy "public read sector videos" on public.sector_videos for select using (true);

drop policy if exists "public read sector bans" on public.sector_bans;
create policy "public read sector bans" on public.sector_bans for select using (true);

drop policy if exists "public read followers" on public.followers;
create policy "public read followers" on public.followers for select using (true);

-- Self-service writes: a signed-in user may only write rows that belong to them
drop policy if exists "insert own profile" on public.users;
create policy "insert own profile" on public.users for insert with check (id = auth.uid());

drop policy if exists "update own profile" on public.users;
create policy "update own profile" on public.users for update using (id = auth.uid());

drop policy if exists "insert own channel" on public.channels;
create policy "insert own channel" on public.channels for insert with check (owner_id = auth.uid());

drop policy if exists "update own channel" on public.channels;
create policy "update own channel" on public.channels for update using (owner_id = auth.uid());

drop policy if exists "delete own channel" on public.channels;
create policy "delete own channel" on public.channels for delete using (owner_id = auth.uid());

drop policy if exists "insert own video" on public.videos;
create policy "insert own video" on public.videos for insert with check (auth.uid() is not null);

drop policy if exists "update own video" on public.videos;
create policy "update own video" on public.videos for update using (uploader_id = auth.uid() or user_id = auth.uid());

drop policy if exists "delete own video" on public.videos;
create policy "delete own video" on public.videos for delete using (uploader_id = auth.uid() or user_id = auth.uid());

drop policy if exists "insert own comment" on public.comments;
create policy "insert own comment" on public.comments for insert with check (user_id = auth.uid());

drop policy if exists "update own comment" on public.comments;
create policy "update own comment" on public.comments for update using (user_id = auth.uid());

drop policy if exists "delete own comment" on public.comments;
create policy "delete own comment" on public.comments for delete using (user_id = auth.uid());

drop policy if exists "insert own follow" on public.followers;
create policy "insert own follow" on public.followers for insert with check (user_id = auth.uid());

drop policy if exists "delete own follow" on public.followers;
create policy "delete own follow" on public.followers for delete using (user_id = auth.uid());

drop policy if exists "insert own sector" on public.sectors;
create policy "insert own sector" on public.sectors for insert with check (auth.uid() is not null);

drop policy if exists "update own sector" on public.sectors;
create policy "update own sector" on public.sectors for update using (owner_id = auth.uid());

drop policy if exists "insert own membership" on public.sector_members;
create policy "insert own membership" on public.sector_members for insert with check (user_id = auth.uid());

drop policy if exists "delete own membership" on public.sector_members;
create policy "delete own membership" on public.sector_members for delete using (user_id = auth.uid());

drop policy if exists "insert own application" on public.channel_early_access_applications;
create policy "insert own application" on public.channel_early_access_applications for insert with check (user_id = auth.uid());

drop policy if exists "read own application" on public.channel_early_access_applications;
create policy "read own application" on public.channel_early_access_applications for select using (user_id = auth.uid());

-- Engagement rows: read + own writes
do $$
declare t text;
begin
  foreach t in array array['comment_likes','comment_dislikes','video_likes','video_dislikes','video_stars'] loop
    execute format('drop policy if exists %I on public.%I', 'public read ' || t, t);
    execute format('create policy %I on public.%I for select using (true)', 'public read ' || t, t);
    execute format('drop policy if exists %I on public.%I', 'insert own ' || t, t);
    execute format('create policy %I on public.%I for insert with check (user_id = auth.uid())', 'insert own ' || t, t);
    execute format('drop policy if exists %I on public.%I', 'delete own ' || t, t);
    execute format('create policy %I on public.%I for delete using (user_id = auth.uid())', 'delete own ' || t, t);
  end loop;
end $$;

-- Rate-limit tables intentionally have no anon policies: the service role
-- key (SUPABASE_SECRET_API_KEY) bypasses RLS for these server-only writes.
