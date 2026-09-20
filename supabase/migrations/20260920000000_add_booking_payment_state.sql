-- Payment is deliberately stored separately from the booking lifecycle.
-- A booking remains `approved` until the renter pays, then becomes `active`
-- only after the renter confirms that the item was received.
alter table public.bookings
  add column if not exists payment_status text not null default 'pending',
  add column if not exists payment_method text,
  add column if not exists payment_reference text,
  add column if not exists paid_at timestamptz;

alter table public.bookings
  drop constraint if exists bookings_payment_status_check;

alter table public.bookings
  add constraint bookings_payment_status_check
  check (payment_status in ('pending', 'processing', 'paid', 'failed', 'refunded'));

alter table public.bookings
  drop constraint if exists bookings_payment_method_check;

alter table public.bookings
  add constraint bookings_payment_method_check
  check (payment_method is null or payment_method in ('esewa', 'khalti'));
