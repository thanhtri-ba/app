-- Photo Cleaner: run once in Supabase -> SQL Editor.

-- Lets a signed-in user delete THEIR OWN account (the app cannot hold the service_role key).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

-- Only logged-in users may call it; anonymous callers may not.
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
