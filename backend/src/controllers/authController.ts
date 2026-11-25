
import type { Request, Response } from "express";
import fs from "node:fs/promises";
import path from "node:path";

import {
  registerSchema,
  loginSchema,
  updateProfileSchema,
  changePasswordSchema,
  forgotPasswordSchema,
  verifyResetCodeSchema,
  resetPasswordSchema,
} from "../validators/authValidator";

import {
  AuthError,
  registerUser,
  loginUser,
  getUserProfileData,
  updateUserProfileData,
  updateUserProfilePhotoData,
  changeUserPassword,
  requestPasswordReset,
  verifyPasswordResetCode,
  resetUserPassword,
} from "../services/authService";

// ==========================================
// ERROR HANDLER
// ==========================================

const handleAuthError = (
  res: Response,
  error: unknown,
  fallbackMessage: string
): void => {
  if (error instanceof AuthError) {
    console.error("[AUTH ERROR]", error.message);

    res.status(error.statusCode).json({
      success: false,
      message: error.message,
    });

    return;
  }

  console.error(`[${fallbackMessage}]`);
  console.error("Detail error:", error);

  res.status(500).json({
    success: false,
    message: fallbackMessage,
  });
};

// ==========================================
// REGISTER
// ==========================================

export const register = async (
  req: Request,
  res: Response
): Promise<void> => {
  console.log("[AUTH REGISTER] Request masuk");

  try {
    const validation = registerSchema.safeParse(req.body);

    if (!validation.success) {
      console.error(
        "[AUTH REGISTER] Validasi gagal:",
        validation.error.issues
      );

      res.status(400).json({
        success: false,
        message:
          validation.error.issues[0]?.message ??
          "Nama, email, dan password wajib diisi. Password minimal 8 dan maksimal 72 karakter.",
      });

      return;
    }

    console.log("[AUTH REGISTER] Validasi berhasil");

    const result = await registerUser(validation.data);

    console.log("[AUTH REGISTER] Registrasi berhasil");

    res.status(201).json({
      success: true,
      message: "Registrasi berhasil.",
      token: result.token,
      data: result.data,
    });
  } catch (error: unknown) {
    handleAuthError(res, error, "Registrasi gagal.");
  }
};

// ==========================================
// LOGIN
// ==========================================

export const login = async (
  req: Request,
  res: Response
): Promise<void> => {
  console.log("[AUTH LOGIN] Request masuk ke controller");

  try {
    const validation = loginSchema.safeParse(req.body);

    if (!validation.success) {
      console.error(
        "[AUTH LOGIN] Validasi gagal:",
        validation.error.issues
      );

      res.status(400).json({
        success: false,
        message:
          validation.error.issues[0]?.message ??
          "Email dan password wajib diisi.",
      });

      return;
    }

    console.log("[AUTH LOGIN] Validasi berhasil, menjalankan loginUser");

    const result = await loginUser(validation.data);

    console.log("[AUTH LOGIN] Login berhasil");

    res.status(200).json({
      success: true,
      message: "Login berhasil.",
      token: result.token,
      data: result.data,
    });
  } catch (error: unknown) {
    console.error("[AUTH LOGIN] Controller menangkap error:", error);

    handleAuthError(res, error, "Login gagal diproses.");
  }
};

// ==========================================
// GET PROFILE
// ==========================================

export const getProfile = async (
  req: Request,
  res: Response
): Promise<void> => {
  console.log("[AUTH PROFILE] Request masuk");

  try {
    const user = await getUserProfileData(req.userId);

    res.status(200).json({
      success: true,
      message: "Profil berhasil diambil.",
      data: user,
    });
  } catch (error: unknown) {
    handleAuthError(res, error, "Gagal mengambil data profil.");
  }
};

// ==========================================
// UPDATE PROFILE
// ==========================================

export const updateProfile = async (
  req: Request,
  res: Response
): Promise<void> => {
  console.log("[AUTH UPDATE PROFILE] Request masuk");

  try {
    const validation = updateProfileSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({
        success: false,
        message:
          validation.error.issues[0]?.message ??
          "Nama dan email wajib diisi.",
      });

      return;
    }

    const user = await updateUserProfileData(
      req.userId,
      validation.data
    );

    res.status(200).json({
      success: true,
      message: "Profil berhasil diperbarui.",
      data: user,
    });
  } catch (error: unknown) {
    handleAuthError(res, error, "Gagal memperbarui profil.");
  }
};

// ==========================================
// UPLOAD PROFILE PHOTO
// ==========================================

export const uploadProfilePhoto = async (
  req: Request,
  res: Response
): Promise<void> => {
  const uploadedFile = req.file;

  console.log("[AUTH UPLOAD PHOTO] Request masuk");

  try {
    if (!uploadedFile) {
      res.status(400).json({
        success: false,
        message: "Pilih foto profil terlebih dahulu.",
      });

      return;
    }

    const relativePhotoPath = `/uploads/profiles/${uploadedFile.filename}`;

    const result = await updateUserProfilePhotoData(
      req.userId,
      relativePhotoPath
    );

    if (result.previousPhoto) {
      const oldFilename = path.basename(result.previousPhoto);

      const oldPhotoPath = path.resolve(
        process.cwd(),
        "uploads",
        "profiles",
        oldFilename
      );

      const profileDirectory = path.resolve(
        process.cwd(),
        "uploads",
        "profiles"
      );

      if (
        path.dirname(oldPhotoPath) === profileDirectory &&
        oldFilename !== uploadedFile.filename
      ) {
        await fs.unlink(oldPhotoPath).catch((error: unknown) => {
          const fileError = error as NodeJS.ErrnoException;

          if (fileError.code !== "ENOENT") {
            console.error(
              "[AUTH UPLOAD PHOTO] Gagal menghapus foto lama:",
              error
            );
          }
        });
      }
    }

    res.status(200).json({
      success: true,
      message: "Foto profil berhasil diperbarui.",
      data: result.user,
    });
  } catch (error: unknown) {
    if (uploadedFile) {
      await fs.unlink(uploadedFile.path).catch(() => undefined);
    }

    handleAuthError(
      res,
      error,
      "Gagal mengunggah foto profil."
    );
  }
};

// ==========================================
// CHANGE PASSWORD
// ==========================================

export const changePassword = async (
  req: Request,
  res: Response
): Promise<void> => {
  console.log("[AUTH CHANGE PASSWORD] Request masuk");

  try {
    const validation = changePasswordSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({
        success: false,
        message:
          validation.error.issues[0]?.message ??
          "Kata sandi lama dan baru wajib diisi.",
      });

      return;
    }

    await changeUserPassword(req.userId, validation.data);

    res.status(200).json({
      success: true,
      message: "Kata sandi berhasil diperbarui.",
    });
  } catch (error: unknown) {
    handleAuthError(res, error, "Gagal memperbarui kata sandi.");
  }
};

// ==========================================
// FORGOT PASSWORD
// ==========================================

export const forgotPassword = async (
  req: Request,
  res: Response
): Promise<void> => {
  console.log("[AUTH FORGOT PASSWORD] Request masuk");

  try {
    const validation = forgotPasswordSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({
        success: false,
        message:
          validation.error.issues[0]?.message ??
          "Email wajib diisi.",
      });

      return;
    }

    await requestPasswordReset(validation.data.email);

    res.status(200).json({
      success: true,
      message: "Jika email terdaftar, kode reset akan tersedia.",
    });
  } catch (error: unknown) {
    handleAuthError(
      res,
      error,
      "Gagal memproses permintaan reset password."
    );
  }
};

// ==========================================
// VERIFY RESET CODE
// ==========================================

export const verifyResetCode = async (
  req: Request,
  res: Response
): Promise<void> => {
  console.log("[AUTH VERIFY RESET CODE] Request masuk");

  try {
    const validation = verifyResetCodeSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({
        success: false,
        message:
          validation.error.issues[0]?.message ??
          "Email dan kode OTP 6 digit wajib diisi.",
      });

      return;
    }

    const resetToken = await verifyPasswordResetCode(
      validation.data
    );

    res.status(200).json({
      success: true,
      message: "Kode berhasil diverifikasi.",
      resetToken,
    });
  } catch (error: unknown) {
    handleAuthError(res, error, "Gagal memverifikasi kode.");
  }
};

// ==========================================
// RESET PASSWORD
// ==========================================

export const resetPassword = async (
  req: Request,
  res: Response
): Promise<void> => {
  console.log("[AUTH RESET PASSWORD] Request masuk");

  try {
    const validation = resetPasswordSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({
        success: false,
        message:
          validation.error.issues[0]?.message ??
          "Token reset dan password baru wajib diisi.",
      });

      return;
    }

    await resetUserPassword(validation.data);

    res.status(200).json({
      success: true,
      message: "Password berhasil direset. Silakan login kembali.",
    });
  } catch (error: unknown) {
    handleAuthError(res, error, "Gagal mereset password.");
  }
};
