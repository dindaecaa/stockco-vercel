
import type { Request, Response, NextFunction } from "express";
import type { RowDataPacket } from "mysql2";
import pool from "../db";

// ==========================================
// CONFIGURATION
// ==========================================

const OWNER_ACCOUNT_ID = 8;

type TeamRole = "owner" | "admin" | "leader" | "staff";

interface TeamRoleRow extends RowDataPacket {
  role: string;
}

// ==========================================
// EXTEND EXPRESS REQUEST
// ==========================================

declare global {
  namespace Express {
    interface Request {
      ownerId?: number;
      teamRole?: TeamRole;
    }
  }
}

// ==========================================
// VALID TEAM ROLES
// ==========================================

const isValidTeamRole = (
  role: string
): role is Exclude<TeamRole, "owner"> => {
  return (
    role === "admin" ||
    role === "leader" ||
    role === "staff"
  );
};

// ==========================================
// INVENTORY ACCESS MIDDLEWARE
// ==========================================

export const inventoryAccessMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    // ==========================================
    // 1. VALIDASI LOGIN
    // ==========================================

    const userId = req.userId;

    if (
      typeof userId !== "number" ||
      !Number.isSafeInteger(userId) ||
      userId <= 0
    ) {
      res.status(401).json({
        success: false,
        message: "Silakan login terlebih dahulu.",
      });
      return;
    }

    // ==========================================
    // 2. OWNER UTAMA
    // ==========================================

    if (userId === OWNER_ACCOUNT_ID) {
      req.ownerId = OWNER_ACCOUNT_ID;
      req.teamRole = "owner";

      next();
      return;
    }

    // ==========================================
    // 3. CARI KEANGGOTAAN TIM
    // ==========================================

    const [rows] = await pool.execute<TeamRoleRow[]>(
      `SELECT role
       FROM team_members
       WHERE owner_id = ?
         AND user_id = ?
       LIMIT 1`,
      [OWNER_ACCOUNT_ID, userId]
    );

    if (rows.length === 0) {
      res.status(403).json({
        success: false,
        message: "Akun Anda tidak memiliki akses ke inventaris ini.",
      });
      return;
    }

    // ==========================================
    // 4. VALIDASI ROLE TIM
    // ==========================================

    const role = rows[0].role;

    if (!isValidTeamRole(role)) {
      res.status(403).json({
        success: false,
        message: "Role akun tidak memiliki akses inventaris.",
      });
      return;
    }

    // ==========================================
    // 5. BERIKAN AKSES INVENTARIS
    // ==========================================

    req.ownerId = OWNER_ACCOUNT_ID;
    req.teamRole = role;

    next();
  } catch (error: unknown) {
    console.error("Inventory access error:", error);

    res.status(500).json({
      success: false,
      message: "Gagal memverifikasi akses inventaris.",
    });
  }
};
