-- 0003: storage bucket used by /api/uploads (signed upload URLs)
insert into storage.buckets (id, name, public)
values ('uploads', 'uploads', true)
on conflict (id) do nothing;
