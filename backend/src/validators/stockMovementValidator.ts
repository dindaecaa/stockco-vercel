
import { z } from "zod";

const positiveInteger = (fieldName: string) =>
  z.preprocess(
    (value) => {
      if (typeof value === "string" && value.trim() !== "") {
        return Number(value);
      }
      return value;
    },
    z.number({
      error: `${fieldName} harus berupa angka.`,
    })
      .int(`${fieldName} harus berupa bilangan bulat.`)
      .positive(`${fieldName} harus lebih dari 0.`)
      .max(2147483647, `${fieldName} terlalu besar.`)
  );

const optionalText = (max: number, fieldName: string) =>
  z.preprocess(
    (value) => {
      if (typeof value === "string" && value.trim() === "") {
        return null;
      }
      return value;
    },
    z.union([
      z.string().trim().max(max, `${fieldName} terlalu panjang.`),
      z.null(),
    ]).optional()
  );

const optionalSupplierId = z.preprocess(
  (value) => {
    if (value === "" || value === null || value === undefined) {
      return null;
    }

    if (typeof value === "string" && value.trim() !== "") {
      return Number(value);
    }

    return value;
  },
  z.union([
    z.number().int().positive().max(2147483647),
    z.null(),
  ]).optional()
);

const optionalTransactionDate = z.preprocess(
  (value) => {
    if (typeof value === "string" && value.trim() === "") {
      return null;
    }
    return value;
  },
  z.union([
    z.string()
      .regex(/^\d{4}-\d{2}-\d{2}$/, "Format tanggal harus YYYY-MM-DD.")
      .refine((value) => {
        const [year, month, day] = value.split("-").map(Number);
        const date = new Date(Date.UTC(year, month - 1, day));

        return (
          date.getUTCFullYear() === year &&
          date.getUTCMonth() === month - 1 &&
          date.getUTCDate() === day
        );
      }, "Tanggal transaksi tidak valid."),
    z.null(),
  ]).optional()
);

export const createStockMovementSchema = z.object({
  product_id: positiveInteger("ID produk"),

  supplier_id: optionalSupplierId,

  customer_name: optionalText(150, "Nama pelanggan"),

  type: z.enum(["in", "out"], {
    error: "Jenis transaksi harus in atau out.",
  }),

  quantity: positiveInteger("Jumlah stok"),

  transaction_date: optionalTransactionDate,

  note: optionalText(10000, "Catatan"),
});

export type CreateStockMovementInput = z.infer<
  typeof createStockMovementSchema
>;
