
import { z } from "zod";

const emailSchema = z.string()
  .trim()
  .toLowerCase()
  .min(1, "Email wajib diisi.")
  .email("Format email tidak valid.")
  .max(150, "Email terlalu panjang.");

const passwordSchema = z.string()
  .min(8, "Password minimal 8 karakter.")
  .max(72, "Password maksimal 72 karakter.");

const phoneSchema = z.preprocess(
  (value) => {
    if (typeof value === "string" && value.trim() === "") {
      return null;
    }

    return value;
  },
  z.string()
    .trim()
    .max(20, "Nomor telepon maksimal 20 karakter.")
    .nullable()
    .optional()
);

export const registerSchema = z.object({
  name: z.string()
    .trim()
    .min(1, "Nama wajib diisi.")
    .max(100, "Nama maksimal 100 karakter."),
  email: emailSchema,
  password: passwordSchema,
});

export const loginSchema = z.object({
  email: emailSchema,
  password: z.string()
    .min(1, "Password wajib diisi."),
});

export const updateProfileSchema = z.object({
  name: z.string()
    .trim()
    .min(1, "Nama wajib diisi.")
    .max(100, "Nama maksimal 100 karakter."),
  email: emailSchema,
  phone: phoneSchema,
});

export const changePasswordSchema = z.object({
  currentPassword: z.string()
    .min(1, "Kata sandi lama wajib diisi."),
  newPassword: passwordSchema,
});

export const forgotPasswordSchema = z.object({
  email: emailSchema,
});

export const verifyResetCodeSchema = z.object({
  email: emailSchema,
  code: z.string()
    .regex(/^\d{6}$/, "Kode OTP 6 digit wajib diisi."),
});

export const resetPasswordSchema = z.object({
  resetToken: z.string()
    .length(64, "Token reset tidak valid."),
  newPassword: passwordSchema,
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;
export type ChangePasswordInput = z.infer<typeof changePasswordSchema>;
export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>;
export type VerifyResetCodeInput = z.infer<typeof verifyResetCodeSchema>;
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;
