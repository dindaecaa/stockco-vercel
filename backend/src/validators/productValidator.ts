import { z } from "zod";

const optionalText = (max: number) =>
  z.string().trim().max(max).nullable().optional();

const nonNegativeInteger = z.coerce
  .number()
  .int("Harus berupa bilangan bulat.")
  .min(0, "Tidak boleh kurang dari 0.");

const positiveId = z.coerce.number().int().positive();

const productPrice = z.coerce
  .number()
  .finite()
  .min(0)
  .max(9999999999.99);

export const productIdSchema = z.object({
  id: positiveId,
});

export const createProductSchema = z.object({
  name: z.string().trim().min(1).max(150),
  supplier_id: positiveId.nullable().optional(),
  reseller_name: optionalText(150),
  sku: optionalText(50),
  description: optionalText(10000),
  stock: nonNegativeInteger,
  minimum_stock: nonNegativeInteger.optional(),
  unit: optionalText(30),
  price: productPrice.optional(),
  location: optionalText(100),
  category_id: positiveId.nullable().optional(),
  category: optionalText(100),
});

export const updateProductSchema = z.object({
  name: z.string().trim().min(1).max(150),
  supplier_id: positiveId.nullable().optional(),
  reseller_name: optionalText(150),
  sku: optionalText(50),
  description: optionalText(10000),
  stock: nonNegativeInteger,
  minimum_stock: nonNegativeInteger.optional(),
  unit: optionalText(30),
  price: productPrice,
  location: optionalText(100),
  category_id: z
    .union([positiveId, z.null(), z.literal("")])
    .optional(),
  category: optionalText(100),
});

export type CreateProductInput = z.infer<
  typeof createProductSchema
>;

export type UpdateProductInput = z.infer<
  typeof updateProductSchema
>;