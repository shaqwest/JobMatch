-- 1. Add missing columns expected by Flutter (profile_model.dart) and cv-parse
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS headline text,
  ADD COLUMN IF NOT EXISTS cv_url text,
  ADD COLUMN IF NOT EXISTS cv_filename text,
  ADD COLUMN IF NOT EXISTS cv_parsed jsonb DEFAULT '{}'::jsonb;

-- 2. Convert experience from text -> jsonb safely so both cv-parse arrays and Profile saves work
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'experience'
      AND data_type = 'text'
  ) THEN
    ALTER TABLE public.profiles
      ALTER COLUMN experience DROP DEFAULT,
      ALTER COLUMN experience TYPE jsonb
      USING CASE
        WHEN experience IS NULL OR btrim(experience) = '' THEN '[]'::jsonb
        WHEN left(btrim(experience), 1) IN ('[', '{') THEN experience::jsonb
        ELSE jsonb_build_array(
          jsonb_build_object(
            'id', '1',
            'title', experience,
            'company', '',
            'duration', '',
            'points', '[]'::jsonb,
            'is_current', false
          )
        )
      END,
      ALTER COLUMN experience SET DEFAULT '[]'::jsonb;
  END IF;
END $$;

-- 3. Auto-create a public.profiles row whenever a new user signs up in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO UPDATE
    SET email = COALESCE(public.profiles.email, EXCLUDED.email);
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 4. Backfill public.profiles for any existing auth.users accounts missing a profile row
INSERT INTO public.profiles (id, email)
SELECT id, email
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 5. Deduplicate any unreferenced duplicate job URLs and enforce unique apply_url
DELETE FROM public.jobs a
USING public.jobs b
WHERE a.created_at > b.created_at
  AND a.apply_url = b.apply_url
  AND NOT EXISTS (
    SELECT 1 FROM public.applications app WHERE app.job_id = a.id
  );

CREATE UNIQUE INDEX IF NOT EXISTS jobs_apply_url_uidx ON public.jobs (apply_url);