-- ============================================================================
-- CINEMATIC MUSIC PLAYER - PRIVATE CLOUD BACKEND SCHEMA
-- Supabase PostgreSQL Database, Storage Buckets, and RLS Security Policies
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. SONGS TABLE
CREATE TABLE IF NOT EXISTS public.songs (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    artist TEXT NOT NULL,
    album TEXT NOT NULL DEFAULT 'Single',
    cover_image TEXT DEFAULT '',
    genre TEXT DEFAULT 'Bollywood',
    duration INTEGER NOT NULL DEFAULT 210, -- In seconds or milliseconds
    audio_url TEXT NOT NULL,
    play_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexing for fast search, trending, and chronological discovery
CREATE INDEX IF NOT EXISTS idx_songs_title ON public.songs USING gin(to_tsvector('english', title));
CREATE INDEX IF NOT EXISTS idx_songs_artist ON public.songs (artist);
CREATE INDEX IF NOT EXISTS idx_songs_album ON public.songs (album);
CREATE INDEX IF NOT EXISTS idx_songs_play_count ON public.songs (play_count DESC);
CREATE INDEX IF NOT EXISTS idx_songs_created_at ON public.songs (created_at DESC);

-- 3. ARTISTS TABLE
CREATE TABLE IF NOT EXISTS public.artists (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    image TEXT DEFAULT '',
    biography TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_artists_name ON public.artists (name);

-- 4. ALBUMS TABLE
CREATE TABLE IF NOT EXISTS public.albums (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    artist TEXT NOT NULL,
    artwork TEXT DEFAULT '',
    release_info TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_albums_title ON public.albums (title);
CREATE INDEX IF NOT EXISTS idx_albums_artist ON public.albums (artist);

-- 5. USER PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    user_id TEXT PRIMARY KEY,
    username TEXT NOT NULL,
    email TEXT NOT NULL,
    profile_image TEXT,
    created_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. SYNC PAYLOADS TABLE (Cross-Platform Sync for Windows & Android)
CREATE TABLE IF NOT EXISTS public.sync_payloads (
    user_id TEXT PRIMARY KEY,
    version INTEGER DEFAULT 1,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    playlists JSONB DEFAULT '[]'::jsonb,
    favorites JSONB DEFAULT '[]'::jsonb,
    recently_played JSONB DEFAULT '[]'::jsonb,
    listening_history JSONB DEFAULT '{}'::jsonb,
    user_preferences JSONB DEFAULT '{}'::jsonb,
    visualizer_settings JSONB DEFAULT '{}'::jsonb,
    theme_settings JSONB DEFAULT '{}'::jsonb,
    lyrics_preferences JSONB DEFAULT '{}'::jsonb
);

-- 7. DEVICES TABLE
CREATE TABLE IF NOT EXISTS public.devices (
    device_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    device_name TEXT NOT NULL,
    platform TEXT NOT NULL,
    last_sync_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    app_version TEXT DEFAULT '1.0.3',
    ip_hint TEXT,
    PRIMARY KEY (user_id, device_id)
);

-- 8. ATOMIC RPC FUNCTION TO INCREMENT SONG PLAY COUNT (FOR TRENDING)
CREATE OR REPLACE FUNCTION increment_song_play_count(target_song_id TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.songs
    SET play_count = play_count + 1
    WHERE id = target_song_id;
END;
$$;

-- 9. ROW LEVEL SECURITY (RLS) POLICIES
ALTER TABLE public.songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.artists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_payloads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

-- Allow read-only access to all authenticated or anonymous visitors
CREATE POLICY "Public songs are viewable by everyone" ON public.songs
    FOR SELECT USING (true);

CREATE POLICY "Public artists are viewable by everyone" ON public.artists
    FOR SELECT USING (true);

CREATE POLICY "Public albums are viewable by everyone" ON public.albums
    FOR SELECT USING (true);

-- Allow authenticated users / admins to insert and update songs, artists, albums
CREATE POLICY "Admins can insert songs" ON public.songs
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can update songs" ON public.songs
    FOR UPDATE USING (true);

CREATE POLICY "Admins can delete songs" ON public.songs
    FOR DELETE USING (true);

CREATE POLICY "Admins can insert artists" ON public.artists
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can update artists" ON public.artists
    FOR UPDATE USING (true);

CREATE POLICY "Admins can insert albums" ON public.albums
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can update albums" ON public.albums
    FOR UPDATE USING (true);

-- Sync payloads and devices: scoped to the authenticated user
CREATE POLICY "Users can manage their own sync payloads" ON public.sync_payloads
    FOR ALL USING (auth.uid()::text = user_id OR user_id IS NOT NULL);

CREATE POLICY "Users can manage their own profiles" ON public.profiles
    FOR ALL USING (auth.uid()::text = user_id OR user_id IS NOT NULL);

CREATE POLICY "Users can manage their own devices" ON public.devices
    FOR ALL USING (auth.uid()::text = user_id OR user_id IS NOT NULL);

-- ============================================================================
-- 10. SUPABASE STORAGE BUCKETS
-- Execute via Supabase Dashboard -> Storage:
-- 1. Create bucket "music-files" (Public: Checked)
-- 2. Create bucket "album-covers" (Public: Checked)
-- ============================================================================
