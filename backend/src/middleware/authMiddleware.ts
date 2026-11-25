
import type { Request, Response, NextFunction } from "express";
import jwt, { type JwtPayload } from "jsonwebtoken";

// ==========================================
// EXTEND EXPRESS REQUEST
// ==========================================

declare global {
  namespace Express {
    interface Request {
      userId?: number;
    }
  }
}

// ==========================================
// AUTHENTICATION MIDDLEWARE
// ==========================================

export const authMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  try {
    // 1. Ambil Authorization Header.

    const authorization = req.headers.authorization;

    if (
      !authorization ||
      !authorization.startsWith("Bearer ")
    ) {
      res.status(401).json({
        success: false,
        message: "Token autentikasi tidak ditemukan.",
      });
      return;
    }

    // 2. Ambil token.

    const token = authorization.slice(7).trim();

    if (!token) {
      res.status(401).json({
        success: false,
        message: "Token autentikasi tidak ditemukan.",
      });
      return;
    }

    // 3. Periksa konfigurasi JWT.

    const jwtSecret = process.env.JWT_SECRET;

    if (!jwtSecret || !jwtSecret.trim()) {
      console.error("JWT_SECRET belum dikonfigurasi.");

      res.status(500).json({
        success: false,
        message: "Konfigurasi autentikasi server belum tersedia.",
      });
      return;
    }

    // 4. Verifikasi token.

    const decoded = jwt.verify(token, jwtSecret, {
      algorithms: ["HS256"],
    });

    // 5. Pastikan payload berbentuk object.

    if (
      typeof decoded !== "object" ||
      decoded === null
    ) {
      res.status(401).json({
        success: false,
        message: "Token tidak valid.",
      });
      return;
    }

    const payload = decoded as JwtPayload;

    // 6. Validasi ID pengguna.
    // Harus berupa angka positif yang aman.

    const userId = payload.id;

    if (
      typeof userId !== "number" ||
      !Number.isSafeInteger(userId) ||
      userId <= 0
    ) {
      res.status(401).json({
        success: false,
        message: "Identitas pengguna dalam token tidak valid.",
      });
      return;
    }

    // 7. Simpan ID pengguna ke Express Request.

    req.userId = userId;

    // 8. Lanjutkan ke middleware berikutnya.

    next();
  } catch (error: unknown) {
    if (error instanceof jwt.TokenExpiredError) {
      res.status(401).json({
        success: false,
        message: "Sesi login telah berakhir. Silakan login kembali.",
      });
      return;
    }

    if (error instanceof jwt.JsonWebTokenError) {
      res.status(401).json({
        success: false,
        message: "Token autentikasi tidak valid.",
      });
      return;
    }

    console.error("Authentication error:", error);

    res.status(500).json({
      success: false,
      message: "Terjadi kesalahan saat memverifikasi autentikasi.",
    });
  }
};
