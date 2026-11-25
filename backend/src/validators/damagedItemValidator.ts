
import { z } from "zod";

const optionalText = (max: number) =>
  z.union([
    z.string().trim().max(max),
    z.null(),
  ]).optional();

const positiveQuantity = z.preprocess(
  (value) => {
    if (typeof value === "string" && value.trim() !== "") {
      return Number(value);
    }

    return value;
  },
  z.number({
    error: "Jumlah barang harus berupa angka.",
  })
    .int("Jumlah barang harus berupa bilangan bulat.")
    .positive("Jumlah barang harus lebih dari 0.")
    .max(2147483647, "Jumlah barang terlalu besar.")
);

export const damagedItemIdSchema = z.object({
  id: z.coerce
    .number()
    .int("ID laporan tidak valid.")
    .positive("ID laporan tidak valid."),
});

export const createDamagedItemSchema = z.object({
  product_name: z.string()
    .trim()
    .min(1, "Nama barang wajib diisi.")
    .max(255),

  product_sku: z.string()
    .trim()
    .min(1, "SKU atau barcode barang wajib diisi.")
    .max(100),

  location: optionalText(255),

  quantity: positiveQuantity,

  reason: z.string()
    .trim()
    .min(1, "Penyebab kerusakan wajib diisi."),

  note: optionalText(10000),

  photo_key: optionalText(500),
});

export const updateDamagedItemStatusSchema = z.object({
  status: z.enum(
    ["Disetujui", "Ditolak"],
    {
      error: "Status hanya boleh Disetujui atau Ditolak.",
    }
  ),
});

export type CreateDamagedItemInput = z.infer<
  typeof createDamagedItemSchema
>;

export type UpdateDamagedItemStatusInput = z.infer<
  typeof updateDamagedItemStatusSchema
>;
