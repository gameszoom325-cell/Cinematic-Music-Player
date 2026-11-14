-- ==============================================================================
-- CINEMATIC MUSIC PLAYER - SUPABASE PRODUCTION DATABASE SCHEMA
-- Compatible with PostgreSQL 15+ and Supabase Row Level Security (RLS)
-- ==============================================================================

-- 1. PROFILES TABLE (User Profile with userId, username, email, profileImage, createdDate, devices)
CREATE TABLE IF NOT EXISTS public.profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    email TEXT NOT NULL,
    profile_image TEXT,
    created_date TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    devices JSONB DEFAULT '[]'::jsonb
);

-- Enable RLS for Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = user_id);


-- 2. SYNC_PAYLOADS TABLE (Full Musical Vault: Playlists, Favorites, History, Settings)
CREATE TABLE IF NOT EXISTS public.sync_payloads (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    version INT DEFAULT 1,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    playlists JSONB DEFAULT '[]'::jsonb,
    favorites JSONB DEFAULT '[]'::jsonb,
    recently_played JSONB DEFAULT '[]'::jsonb,
    listening_history JSONB DEFAULT '{}'::jsonb,
    user_preferences JSONB DEFAULT '{}'::jsonb,
    visualizer_settings JSONB DEFAULT '{}'::jsonb,
    theme_settings JSONB DEFAULT '{}'::jsonb,
    lyrics_preferences JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS for Sync Payloads
ALTER TABLE public.sync_payloads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own sync payload"
    ON public.sync_payloads FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sync payload"
    ON public.sync_payloads FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sync payload"
    ON public.sync_payloads FOR UPDATE
    USING (auth.uid() = user_id);


-- 3. DEVICES TABLE (Active Hardware Devices: Windows Laptops, Android Phones)
CREATE TABLE IF NOT EXISTS public.devices (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT NOT NULL,
    platform TEXT NOT NULL,
    last_sync_time TIMESTAMPTZ DEFAULT NOW(),
    app_version TEXT DEFAULT '1.0.0',
    ip_hint TEXT DEFAULT '127.0.0.1',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- Enable RLS for Devices
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own devices"
    ON public.devices FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert/update own devices"
    ON public.devices FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can modify own devices"
    ON public.devices FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own devices"
    ON public.devices FOR DELETE
    USING (auth.uid() = user_id);


-- 4. AUTOMATIC PROFILE CREATION TRIGGER
-- Creates a profile row automatically whenever a user signs up via auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (user_id, username, email, profile_image, created_date, devices)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    new.email,
    new.raw_user_meta_data->>'profile_image',
    NOW(),
    '[]'::jsonb
  )
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.sync_payloads (user_id, version, updated_at, playlists, favorites, recently_played)
  VALUES (new.id, 1, NOW(), '[]'::jsonb, '[]'::jsonb, '[]'::jsonb)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
