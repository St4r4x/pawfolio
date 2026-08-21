-- A vet visit's own visit_date is the natural "next appointment" reminder —
-- a separate next_visit_date field just duplicated it. Recreate the view
-- before dropping the column it currently references.
create or replace view public.upcoming_reminders
  with (security_invoker = true) as
  select pet_id, name as label, next_due_date as due_date
  from public.vaccinations
  where next_due_date is not null
  union all
  select pet_id, name as label, next_due_date as due_date
  from public.treatments
  where next_due_date is not null
  union all
  select pet_id, reason as label, visit_date as due_date
  from public.vet_visits;

alter table public.vet_visits drop column next_visit_date;
