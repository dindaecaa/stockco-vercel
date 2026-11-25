
import type {
  ResultSetHeader,
  RowDataPacket,
} from "mysql2";

import pool from "../db";

export interface UserRow extends RowDataPacket {
  id: number;
  name: string;
  email: string;
  password: string;
  role: string | null;
}

export interface PasswordResetOtpRow extends RowDataPacket {
  id: number;
  user_id: number;
  otp_hash: string;
  reset_token_hash: string | null;
  attempts: number;
  verified_at: Date | string | null;
}

export interface UserProfileRow extends RowDataPacket {
  id: number;
  name: string;
  email: string;
  phone: string | null;
  profile_photo: string | null;
  role: string | null;
}

export const findUserByEmail = async (
  email: string
): Promise<UserRow | null> => {
  const [rows] = await pool.execute<UserRow[]>(
    `SELECT id, name, email, password, role
     FROM users
     WHERE email = ?
     LIMIT 1`,
    [email]
  );

  return rows[0] ?? null;
};

export const findUserIdByEmail = async (
  email: string
): Promise<{ id: number } | null> => {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT id
     FROM users
     WHERE email = ?
     LIMIT 1`,
    [email]
  );

  if (!rows[0]) {
    return null;
  }

  return {
    id: Number(rows[0].id),
  };
};

export const findUserById = async (
  userId: number
): Promise<UserRow | null> => {
  const [rows] = await pool.execute<UserRow[]>(
    `SELECT id, name, email, password, role
     FROM users
     WHERE id = ?
     LIMIT 1`,
    [userId]
  );

  return rows[0] ?? null;
};

export const findUserProfileById = async (
  userId: number
): Promise<UserProfileRow | null> => {
  const [rows] = await pool.execute<UserProfileRow[]>(
    `SELECT
       id,
       name,
       email,
       phone,
       profile_photo,
       role
     FROM users
     WHERE id = ?
     LIMIT 1`,
    [userId]
  );

  return rows[0] ?? null;
};

export const findEmailOwner = async (
  email: string,
  excludedUserId: number
): Promise<{ id: number } | null> => {
  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT id
     FROM users
     WHERE email = ? AND id <> ?
     LIMIT 1`,
    [email, excludedUserId]
  );

  if (!rows[0]) {
    return null;
  }

  return {
    id: Number(rows[0].id),
  };
};

export const createUser = async (
  name: string,
  email: string,
  hashedPassword: string
): Promise<number> => {
  const [result] = await pool.execute<ResultSetHeader>(
    `INSERT INTO users (name, email, password, role)
     VALUES (?, ?, ?, 'user')`,
    [name, email, hashedPassword]
  );

  return result.insertId;
};

export const updateUserProfile = async (
  userId: number,
  name: string,
  email: string,
  phone: string | null
): Promise<void> => {
  await pool.execute<ResultSetHeader>(
    `UPDATE users
     SET name = ?,
         email = ?,
         phone = ?
     WHERE id = ?`,
    [name, email, phone, userId]
  );
};

export const updateUserProfilePhoto = async (
  userId: number,
  profilePhoto: string
): Promise<void> => {
  await pool.execute<ResultSetHeader>(
    `UPDATE users
     SET profile_photo = ?
     WHERE id = ?`,
    [profilePhoto, userId]
  );
};

export const updateUserPassword = async (
  userId: number,
  hashedPassword: string
): Promise<void> => {
  await pool.execute<ResultSetHeader>(
    `UPDATE users
     SET password = ?
     WHERE id = ?`,
    [hashedPassword, userId]
  );
};

export const deletePasswordResetOtps = async (
  userId: number
): Promise<void> => {
  await pool.execute(
    `DELETE FROM password_reset_otps
     WHERE user_id = ?`,
    [userId]
  );
};

export const createPasswordResetOtp = async (
  userId: number,
  otpHash: string
): Promise<void> => {
  await pool.execute(
    `INSERT INTO password_reset_otps
     (user_id, otp_hash, attempts, expires_at)
     VALUES (?, ?, 0, DATE_ADD(NOW(), INTERVAL 5 MINUTE))`,
    [userId, otpHash]
  );
};

export const findActivePasswordResetOtp = async (
  userId: number
): Promise<PasswordResetOtpRow | null> => {
  const [rows] = await pool.execute<PasswordResetOtpRow[]>(
    `SELECT id, user_id, otp_hash, reset_token_hash,
            attempts, verified_at
     FROM password_reset_otps
     WHERE user_id = ?
       AND verified_at IS NULL
       AND expires_at > NOW()
     ORDER BY id DESC
     LIMIT 1`,
    [userId]
  );

  return rows[0] ?? null;
};

export const expirePasswordResetOtp = async (
  otpId: number
): Promise<void> => {
  await pool.execute(
    `UPDATE password_reset_otps
     SET expires_at = NOW()
     WHERE id = ?`,
    [otpId]
  );
};

export const incrementOtpAttempts = async (
  otpId: number
): Promise<number> => {
  await pool.execute(
    `UPDATE password_reset_otps
     SET attempts = attempts + 1,
         expires_at = IF(attempts + 1 >= 5, NOW(), expires_at)
     WHERE id = ?`,
    [otpId]
  );

  const [rows] = await pool.execute<RowDataPacket[]>(
    `SELECT attempts
     FROM password_reset_otps
     WHERE id = ?
     LIMIT 1`,
    [otpId]
  );

  return Number(rows[0]?.attempts ?? 0);
};

export const verifyPasswordResetOtp = async (
  otpId: number,
  resetTokenHash: string
): Promise<void> => {
  await pool.execute(
    `UPDATE password_reset_otps
     SET reset_token_hash = ?,
         verified_at = NOW(),
         expires_at = DATE_ADD(NOW(), INTERVAL 10 MINUTE)
     WHERE id = ?`,
    [resetTokenHash, otpId]
  );
};

export const findPasswordResetByTokenHash = async (
  resetTokenHash: string
): Promise<PasswordResetOtpRow | null> => {
  const [rows] = await pool.execute<PasswordResetOtpRow[]>(
    `SELECT id, user_id, otp_hash, reset_token_hash,
            attempts, verified_at
     FROM password_reset_otps
     WHERE reset_token_hash = ?
       AND verified_at IS NOT NULL
       AND expires_at > NOW()
     LIMIT 1`,
    [resetTokenHash]
  );

  return rows[0] ?? null;
};

export const deletePasswordResetOtpById = async (
  otpId: number
): Promise<void> => {
  await pool.execute(
    `DELETE FROM password_reset_otps
     WHERE id = ?`,
    [otpId]
  );
};
