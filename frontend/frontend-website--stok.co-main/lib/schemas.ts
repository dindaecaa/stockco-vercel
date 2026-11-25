
import { z } from "zod";

export const skuSchema = z.object({
  name: z
    .string()
    .trim()
    .min(1, "Nama produk wajib diisi."),

  category: z
    .string()
    .trim()
    .min(1, "Kategori wajib dipilih."),

  stock: z
    .number()
    .int("Stok harus berupa bilangan bulat.")
    .min(0, "Stok tidak boleh negatif."),

  location: z
    .string()
    .trim()
    .min(1, "Lokasi wajib diisi."),

  description: z
    .string()
    .trim(),
});

export type SKUSchema = z.infer<typeof skuSchema>;
