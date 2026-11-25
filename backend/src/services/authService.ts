import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import {
  createHash,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from "node:crypto";

import {
  findUserByEmail,
  findUserById,
  findUserIdByEmail,
  findUserProfileById,
  findEmailOwner,
  createUser,
  updateUserProfile,
  updateUserProfilePhoto,
  updateUserPassword,
  deletePasswordResetOtps,
  createPasswordResetOtp,
  findActivePasswordResetOtp,
  expirePasswordResetOtp,
  incrementOtpAttempts,
  verifyPasswordResetOtp,
  findPasswordResetByTokenHash,
  deletePasswordResetOtpById,
} from "../repositories/authRepository";

import type { UserRow } from "../repositories/authRepository";

import type {
  RegisterDto,
  LoginDto,
  UpdateProfileDto,
  ChangePasswordDto,
  VerifyResetCodeDto,
  ResetPasswordDto,
  AuthResultDto,
  UserProfileDto,
} from "../dto/authDto";

export class AuthError extends Error {
  statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.name = "AuthError";
    this.statusCode = statusCode;
  }
}

const getJwtSecret = (): string => {
  const secret = process.env.JWT_SECRET;

  if (!secret) {
    throw new AuthError(
      "Konfigurasi autentikasi belum lengkap.",
      500
    );
  }

  return secret;
};

const hashValue = (value: string): string => {
  return createHash("sha256")
    .update(value)
    .digest("hex");
};

const safeHashCompare = (
  first: string,
  second: string
): boolean => {
  const firstBuffer = Buffer.from(first, "hex");
  const secondBuffer = Buffer.from(second, "hex");

  return (
    firstBuffer.length === secondBuffer.length &&
    timingSafeEqual(firstBuffer, secondBuffer)
  );
};

const isDuplicateEntry = (error: unknown): boolean => {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    error.code === "ER_DUP_ENTRY"
  );
};

const createAuthToken = (
  user: Pick<UserRow, "id" | "email" | "role">
): string => {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role || "user",
    },
    getJwtSecret(),
    { expiresIn: "2h" }
  );
};

// ================================
// REGISTER
// ================================

export const registerUser = async (
  input: RegisterDto
): Promise<AuthResultDto> => {
  const name = input.name.trim();
  const email = input.email.trim().toLowerCase();

  getJwtSecret();

  const existingUser = await findUserByEmail(email);

  if (existingUser) {
    throw new AuthError("Email sudah terdaftar.", 409);
  }

  const hashedPassword = await bcrypt.hash(input.password, 12);

  try {
    const userId = await createUser(
      name,
      email,
      hashedPassword
    );

    const user = {
      id: userId,
      name,
      email,
      role: "user",
    };

    const token = createAuthToken(user);

    return {
      token,
      data: user,
    };
  } catch (error: unknown) {
    if (isDuplicateEntry(error)) {
      throw new AuthError("Email sudah terdaftar.", 409);
    }

    throw error;
  }
};

// ================================
// LOGIN
// ================================

export const loginUser = async (
  input: LoginDto
): Promise<AuthResultDto> => {
  const email = input.email.trim().toLowerCase();

  const user = await findUserByEmail(email);

  if (!user) {
    throw new AuthError(
      "Email atau password salah.",
      401
    );
  }

  const passwordMatch = await bcrypt.compare(
    input.password,
    user.password
  );

  if (!passwordMatch) {
    throw new AuthError(
      "Email atau password salah.",
      401
    );
  }

  const token = createAuthToken(user);

  return {
    token,
    data: {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role || "user",
    },
  };
};

// ================================
// GET PROFILE
// ================================

export const getUserProfileData = async (
  userId: number | undefined
): Promise<UserProfileDto> => {
  if (!userId) {
    throw new AuthError(
      "Autentikasi diperlukan.",
      401
    );
  }

  const user = await findUserProfileById(userId);

  if (!user) {
    throw new AuthError(
      "Data pengguna tidak ditemukan.",
      404
    );
  }

  return user;
};

// ================================
// UPDATE PROFILE
// ================================

export const updateUserProfileData = async (
  userId: number | undefined,
  input: UpdateProfileDto
): Promise<UserProfileDto> => {
  if (!userId) {
    throw new AuthError(
      "Autentikasi diperlukan.",
      401
    );
  }

  const name = input.name.trim();
  const email = input.email.trim().toLowerCase();
  const phone = input.phone?.trim() || null;

  const existingUser = await findEmailOwner(email, userId);

  if (existingUser) {
    throw new AuthError(
      "Email sudah digunakan oleh akun lain.",
      409
    );
  }

  try {
    await updateUserProfile(
      userId,
      name,
      email,
      phone
    );
  } catch (error: unknown) {
    if (isDuplicateEntry(error)) {
      throw new AuthError(
        "Email sudah digunakan oleh akun lain.",
        409
      );
    }

    throw error;
  }

  const updatedUser = await findUserProfileById(userId);

  if (!updatedUser) {
    throw new AuthError(
      "Data pengguna tidak ditemukan.",
      404
    );
  }

  return updatedUser;
};

// ================================
// UPDATE PROFILE PHOTO
// ================================

export interface UpdateProfilePhotoResult {
  user: UserProfileDto;
  previousPhoto: string | null;
}

export const updateUserProfilePhotoData = async (
  userId: number | undefined,
  profilePhoto: string
): Promise<UpdateProfilePhotoResult> => {
  if (!userId) {
    throw new AuthError(
      "Autentikasi diperlukan.",
      401
    );
  }

  if (!profilePhoto || !profilePhoto.trim()) {
    throw new AuthError(
      "File foto profil tidak valid.",
      400
    );
  }

  const currentUser = await findUserProfileById(userId);

  if (!currentUser) {
    throw new AuthError(
      "Data pengguna tidak ditemukan.",
      404
    );
  }

  await updateUserProfilePhoto(
    userId,
    profilePhoto
  );

  const updatedUser = await findUserProfileById(userId);

  if (!updatedUser) {
    throw new AuthError(
      "Gagal mengambil data profil setelah upload.",
      500
    );
  }

  return {
    user: updatedUser,
    previousPhoto: currentUser.profile_photo,
  };
};

// ================================
// CHANGE PASSWORD
// ================================

export const changeUserPassword = async (
  userId: number | undefined,
  input: ChangePasswordDto
): Promise<void> => {
  if (!userId) {
    throw new AuthError(
      "Autentikasi diperlukan.",
      401
    );
  }

  const user = await findUserById(userId);

  if (!user) {
    throw new AuthError(
      "Pengguna tidak ditemukan.",
      404
    );
  }

  const passwordMatch = await bcrypt.compare(
    input.currentPassword,
    user.password
  );

  if (!passwordMatch) {
    throw new AuthError(
      "Kata sandi saat ini tidak sesuai.",
      401
    );
  }

  const samePassword = await bcrypt.compare(
    input.newPassword,
    user.password
  );

  if (samePassword) {
    throw new AuthError(
      "Kata sandi baru harus berbeda.",
      400
    );
  }

  const hashedPassword = await bcrypt.hash(
    input.newPassword,
    12
  );

  await updateUserPassword(userId, hashedPassword);
};

// ================================
// FORGOT PASSWORD - REQUEST OTP
// ================================

export const requestPasswordReset = async (
  email: string
): Promise<void> => {
  const normalizedEmail = email.trim().toLowerCase();

  const user = await findUserIdByEmail(normalizedEmail);

  if (!user) {
    return;
  }

  const otp = randomInt(100000, 1000000).toString();
  const otpHash = hashValue(otp);

  await deletePasswordResetOtps(user.id);

  await createPasswordResetOtp(
    user.id,
    otpHash
  );

  if (process.env.NODE_ENV !== "production") {
    console.log("\n====================================");
    console.log("STOCK.CO - PASSWORD RESET OTP");
    console.log("Email:", normalizedEmail);
    console.log("OTP:", otp);
    console.log("Berlaku: 5 menit");
    console.log("====================================\n");
  }
};

// ================================
// VERIFY RESET CODE
// ================================

export const verifyPasswordResetCode = async (
  input: VerifyResetCodeDto
): Promise<string> => {
  const email = input.email.trim().toLowerCase();

  const user = await findUserIdByEmail(email);

  if (!user) {
    throw new AuthError(
      "Kode tidak valid atau sudah kedaluwarsa.",
      400
    );
  }

  const record = await findActivePasswordResetOtp(user.id);

  if (!record) {
    throw new AuthError(
      "Kode tidak valid atau sudah kedaluwarsa.",
      400
    );
  }

  if (record.attempts >= 5) {
    await expirePasswordResetOtp(record.id);

    throw new AuthError(
      "Batas percobaan OTP sudah habis. Minta kode baru.",
      429
    );
  }

  const submittedHash = hashValue(input.code);

  if (!safeHashCompare(submittedHash, record.otp_hash)) {
    const nextAttempts = await incrementOtpAttempts(record.id);

    throw new AuthError(
      nextAttempts >= 5
        ? "Batas percobaan OTP habis. Minta kode baru."
        : `Kode OTP salah. Sisa percobaan: ${5 - nextAttempts}.`,
      400
    );
  }

  const resetToken = randomBytes(32).toString("hex");
  const resetTokenHash = hashValue(resetToken);

  await verifyPasswordResetOtp(
    record.id,
    resetTokenHash
  );

  return resetToken;
};

// ================================
// RESET PASSWORD
// ================================

export const resetUserPassword = async (
  input: ResetPasswordDto
): Promise<void> => {
  const resetTokenHash = hashValue(input.resetToken);

  const record = await findPasswordResetByTokenHash(
    resetTokenHash
  );

  if (!record) {
    throw new AuthError(
      "Token reset tidak valid atau sudah kedaluwarsa.",
      400
    );
  }

  const user = await findUserById(record.user_id);

  if (!user) {
    throw new AuthError(
      "Pengguna tidak ditemukan.",
      404
    );
  }

  const samePassword = await bcrypt.compare(
    input.newPassword,
    user.password
  );

  if (samePassword) {
    throw new AuthError(
      "Password baru harus berbeda dari password lama.",
      400
    );
  }

  const hashedPassword = await bcrypt.hash(
    input.newPassword,
    12
  );

  await updateUserPassword(
    record.user_id,
    hashedPassword
  );

  await deletePasswordResetOtpById(record.id);
};
