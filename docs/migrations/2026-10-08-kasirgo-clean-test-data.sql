-- Cleanup test data after BATCH #2 deployment (2026-10-08)
-- Hapus: customer_referrals + referral_codes, doctor_intake, outlet_targets, 
--         customer test registrations, dan reset flags tertentu.

-- 1. Hapus referral codes & tracking (test generated)
DELETE FROM customer_referrals;
DELETE FROM referral_codes;

-- 2. Hapus intake wizard yang sudah dijalankan (test runs)
DELETE FROM doctor_intake WHERE created_at > '2026-09-01';

-- 3. Reset AI config flags (test provider/api_key)
UPDATE outlet_ai_configs SET unlimited_tokens = false WHERE model IS NOT NULL AND unlimited_tokens = true;

-- 4. Supporter trial status (jika ada status trial aktif di table supporters)
UPDATE supporters SET status = 'none', end_date = NULL WHERE tier = 'trial';

-- 5. Customer registration cleanup (nama "Test" atau nomor dummy)
-- Catatan: kolom phone tidak ada, hanya name + outlet_id
DELETE FROM customers WHERE (name ilike '%Test%' OR note like '%Test%') and created_at > '2026-09-01';

-- Catatan: transaction_tests dan payment_orders KGO-* dibersihkan secara manual via Supabase dashboard 
-- karena butuh audit trail lebih detail.
