
import { z } from "zod";

const positiveId = z.preprocess(
  (value) => {
    if (typeof value === "string" && value.trim() !== "") {
      return Number(value);
    }
    return value;
  },
  z.number()
    .int("ID tidak valid.")
    .positive("ID tidak valid.")
    .max(2147483647, "ID terlalu besar.")
);

const optionalBranchId = z.preprocess(
  (value) => {
    if (
      value === undefined ||
      value === null ||
      value === ""
    ) {
      return null;
    }

    if (typeof value === "string" && value.trim() !== "") {
      return Number(value);
    }

    return value;
  },
  z.union([
    z.number()
      .int("ID cabang tidak valid.")
      .positive("ID cabang tidak valid.")
      .max(2147483647, "ID cabang tidak valid."),
    z.null(),
  ])
);

export const teamMemberIdSchema = z.object({
  id: positiveId,
});

export const inviteTeamMemberSchema = z.object({
  email: z.string()
    .trim()
    .toLowerCase()
    .min(1, "Email anggota wajib diisi.")
    .email("Format email tidak valid.")
    .max(254, "Email terlalu panjang."),
  branch_id: optionalBranchId,
});

export const updateMemberRoleSchema = z.object({
  role: z.enum(["admin", "leader", "staff"], {
    error: "Role hanya boleh admin, leader, atau staff.",
  }),
});

export type InviteTeamMemberInput = z.infer<
  typeof inviteTeamMemberSchema
>;

export type UpdateMemberRoleInput = z.infer<
  typeof updateMemberRoleSchema
>;

export type TeamMemberIdInput = z.infer<
  typeof teamMemberIdSchema
>;
