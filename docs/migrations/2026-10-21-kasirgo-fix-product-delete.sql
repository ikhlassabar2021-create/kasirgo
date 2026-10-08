-- Fix: hapus produk gagal karena FK transaction_items -> products (RESTRICT).
-- transaction_items sudah menyimpan snapshot product_name, jadi riwayat aman.
-- Ubah FK jadi ON DELETE SET NULL: item transaksi tetap ada, product_id jadi NULL.
ALTER TABLE public.transaction_items
  DROP CONSTRAINT IF EXISTS transaction_items_product_id_fkey;

ALTER TABLE public.transaction_items
  ADD CONSTRAINT transaction_items_product_id_fkey
  FOREIGN KEY (product_id) REFERENCES public.products(id)
  ON DELETE SET NULL;
