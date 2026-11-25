import {
  findBranchesByOwner,
  createBranchRecord,
  deleteBranchRecord,
} from "../repositories/branchRepository";

import type { BranchRow } from "../repositories/branchRepository";

const OWNER_ACCOUNT_ID = 8;

export class BranchError extends Error {
  statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.name = "BranchError";
    this.statusCode = statusCode;
  }
}

interface BranchAccess {
  userId?: number;
  ownerId?: number;
  teamRole?: string;
}

const validateInventoryAccess = (
  ownerId: number | undefined
): number => {
  if (!ownerId || !Number.isInteger(ownerId) || ownerId <= 0) {
    throw new BranchError(
      "Akses inventaris tidak ditemukan.",
      403
    );
  }

  return ownerId;
};

const validateBranchManagementAccess = (
  access: BranchAccess
): void => {
  const canManage =
    access.userId === OWNER_ACCOUNT_ID ||
    access.teamRole === "admin";

  if (!canManage) {
    throw new BranchError(
      "Hanya Owner dan Admin yang boleh mengelola cabang.",
      403
    );
  }
};

export const getBranchesData = async (
  ownerId: number | undefined
): Promise<BranchRow[]> => {
  const validOwnerId = validateInventoryAccess(ownerId);

  return findBranchesByOwner(validOwnerId);
};

export const createBranch = async (
  access: BranchAccess,
  name: string
): Promise<BranchRow> => {
  const ownerId = validateInventoryAccess(access.ownerId);

  validateBranchManagementAccess(access);

  try {
    const branch = await createBranchRecord(ownerId, name);

    if (!branch) {
      throw new BranchError(
        "Gagal mengambil data cabang setelah ditambahkan.",
        500
      );
    }

    return branch;
  } catch (error: unknown) {
    if (
      typeof error === "object" &&
      error !== null &&
      "code" in error &&
      error.code === "ER_DUP_ENTRY"
    ) {
      throw new BranchError(
        "Nama cabang tersebut sudah digunakan.",
        409
      );
    }

    throw error;
  }
};

export const deleteBranch = async (
  access: BranchAccess,
  branchId: number
): Promise<void> => {
  const ownerId = validateInventoryAccess(access.ownerId);

  validateBranchManagementAccess(access);

  const deleted = await deleteBranchRecord(branchId, ownerId);

  if (!deleted) {
    throw new BranchError(
      "Cabang tidak ditemukan.",
      404
    );
  }
};