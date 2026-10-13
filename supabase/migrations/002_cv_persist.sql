alter table profiles add column if not exists cv_url text;
alter table profiles add column if not exists cv_filename text;
alter table profiles add column if not exists cv_parsed jsonb;
