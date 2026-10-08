-- =============================================================================
-- 2026-10-08-kasirgo-clean-rcb-test-data.sql
-- Bersihkan data uji E2E Payment Gateway RCB (sesi 2026-10-08).
--   - payment_orders: order smoke test (external_id TESTSMOKE*) + E2E supporter.
--   - supporters: baris langganan uji yang teraktivasi webhook (pg_reference_id).
-- =============================================================================

\set ON_ERROR_STOP on
BEGIN;

DELETE FROM public.payment_orders
 WHERE external_id IN ('TESTSMOKE1', 'TESTSMOKE2')
    OR external_id LIKE 'SUP-TEST%'
    OR rcb_order_id IN ('API-5UKDOSAGJ', 'API-RH9AECX3C', 'API-BQSDYS8IM');

DELETE FROM public.supporters
 WHERE pg_reference_id IN ('API-RH9AECX3C') OR id = '11903fd8-0fee-4164-8f92-1a97d947e311';

COMMIT;
