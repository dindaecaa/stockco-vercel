import { z } from "zod";

const positiveId = z.preprocess(
  (value) => {
    if (typeof value === "string" && value.trim() !== "") {
      return Number(value);
    }

    return value;
  },
  z.number()
    .int("ID cabang tidak valid.")
    .positive("ID cabang tidak valid.")
    .max(2147483647, "ID cabang tidak valid.")
);

export const branchIdSchema = z.object({
  id: positiveId,
});

export const createBranchSchema = z.object({
  name: z.string()
    .trim()
    .min(1, "Nama cabang wajib diisi.")
    .max(150, "Nama cabang maksimal 150 karakter."),
});

export type CreateBranchInput = z.infer<
  typeof createBranchSchema
>;