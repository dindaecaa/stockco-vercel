
import { z } from "zod";

const optionalText = z.union([
  z.string(),
  z.null(),
]).optional();

const emailSchema = optionalText.refine(
  (value) =>
    value === undefined ||
    value === null ||
    value.trim() === "" ||
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim()),
  "Format email supplier tidak valid."
);

export const supplierIdSchema = z.object({
  id: z.coerce.number().int().positive(
    "ID supplier tidak valid."
  ),
});

export const createSupplierSchema = z.object({
  name: z.string()
    .trim()
    .min(1, "Nama supplier wajib diisi."),
  phone: optionalText,
  email: emailSchema,
  address: optionalText,
});

export const updateSupplierSchema = z.object({
  name: z.string()
    .trim()
    .min(1, "Nama supplier wajib diisi."),
  phone: optionalText,
  email: emailSchema,
  address: optionalText,
});

export type CreateSupplierInput = z.infer<
  typeof createSupplierSchema
>;

export type UpdateSupplierInput = z.infer<
  typeof updateSupplierSchema
>;
