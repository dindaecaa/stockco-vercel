
import { z } from "zod";

export const categoryIdSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export const createCategorySchema = z.object({
  name: z.string().trim().min(1, "Nama kategori wajib diisi.").max(
    100,
    "Nama kategori maksimal 100 karakter."
  ),
  description: z.string().trim().max(10000).nullable().optional(),
});

export const updateCategorySchema = createCategorySchema;

export type CreateCategoryInput = z.infer<
  typeof createCategorySchema
>;

export type UpdateCategoryInput = z.infer<
  typeof updateCategorySchema
>;
