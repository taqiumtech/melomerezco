-- Dar acceso al panel /admin a un usuario.
-- 1) En Supabase → Authentication → Users → "Add user" crea tu usuario (correo + contraseña,
--    marca "Auto Confirm User").
-- 2) Cambia el correo de abajo y corre este SQL.
insert into public.admins (user_id)
select id from auth.users where email = 'TU_CORREO@ejemplo.cl'
on conflict do nothing;
