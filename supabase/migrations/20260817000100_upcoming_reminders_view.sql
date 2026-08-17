create view public.upcoming_reminders
  with (security_invoker = true) as
  select pet_id, name as label, next_due_date as due_date
  from public.vaccinations
  where next_due_date is not null
  union all
  select pet_id, name as label, next_due_date as due_date
  from public.treatments
  where next_due_date is not null
  union all
  select pet_id, reason as label, next_visit_date as due_date
  from public.vet_visits
  where next_visit_date is not null;

-- New relations aren't auto-exposed to the API role here (auto_expose_new_tables
-- is unset in config.toml, per the grant gap already hit in Task 2) — grant the
-- view explicitly or the client's authenticated SELECT will hit a permission error.
grant select on public.upcoming_reminders to authenticated;
