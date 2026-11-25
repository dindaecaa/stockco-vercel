import type { Request, Response } from "express";

import {
  branchIdSchema,
  createBranchSchema,
} from "../validators/branchValidator";

import {
  BranchError,
  getBranchesData,
  createBranch,
  deleteBranch,
} from "../services/branchService";

const handleBranchError = (
  res: Response,
  error: unknown,
  fallbackMessage: string
): void => {
  if (error instanceof BranchError) {
    res.status(error.statusCode).json({
      success: false,
      message: error.message,
    });
    return;
  }

  console.error(fallbackMessage, error);

  res.status(500).json({
    success: false,
    message: fallbackMessage,
  });
};

// GET: Mengambil seluruh cabang milik Owner inventaris.
export const getBranches = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const branches = await getBranchesData(req.ownerId);

    res.status(200).json({
      success: true,
      message: "Data cabang berhasil diambil.",
      data: branches,
    });
  } catch (error: unknown) {
    handleBranchError(
      res,
      error,
      "Gagal mengambil data cabang."
    );
  }
};

// POST: Menambahkan cabang baru.
export const createBranchController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const validation = createBranchSchema.safeParse(req.body);

    if (!validation.success) {
      res.status(400).json({
        success: false,
        message: validation.error.issues[0]?.message ??
          "Data cabang tidak valid.",
      });
      return;
    }

    const branch = await createBranch(
      {
        userId: req.userId,
        ownerId: req.ownerId,
        teamRole: req.teamRole,
      },
      validation.data.name
    );

    res.status(201).json({
      success: true,
      message: "Cabang berhasil ditambahkan.",
      data: branch,
    });
  } catch (error: unknown) {
    handleBranchError(
      res,
      error,
      "Gagal menambahkan cabang."
    );
  }
};

// DELETE: Menghapus cabang milik Owner inventaris.
export const deleteBranchController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const validation = branchIdSchema.safeParse({
      id: req.params.id,
    });

    if (!validation.success) {
      res.status(400).json({
        success: false,
        message: validation.error.issues[0]?.message ??
          "ID cabang tidak valid.",
      });
      return;
    }

    await deleteBranch(
      {
        userId: req.userId,
        ownerId: req.ownerId,
        teamRole: req.teamRole,
      },
      validation.data.id
    );

    res.status(200).json({
      success: true,
      message: "Cabang berhasil dihapus.",
    });
  } catch (error: unknown) {
    handleBranchError(
      res,
      error,
      "Gagal menghapus cabang."
    );
  }
};