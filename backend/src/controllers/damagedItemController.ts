
import type { Request, Response } from "express";
import { ZodError } from "zod";

import {
  damagedItemIdSchema,
  createDamagedItemSchema,
  updateDamagedItemStatusSchema,
} from "../validators/damagedItemValidator";

import {
  damagedItemService,
  DamagedItemServiceError,
} from "../services/damagedItemService";

function getOwnerId(req: Request): number | null {
  const ownerId = req.ownerId;

  if (
    typeof ownerId !== "number" ||
    !Number.isSafeInteger(ownerId) ||
    ownerId <= 0
  ) {
    return null;
  }

  return ownerId;
}

function handleError(
  res: Response,
  error: unknown,
  defaultMessage: string
): void {
  if (error instanceof DamagedItemServiceError) {
    res.status(error.statusCode).json({
      success: false,
      message: error.message,
    });
    return;
  }

  if (error instanceof ZodError) {
    res.status(400).json({
      success: false,
      message:
        error.issues[0]?.message ||
        "Data laporan barang rusak tidak valid.",
      errors: error.issues,
    });
    return;
  }

  console.error(defaultMessage, error);

  res.status(500).json({
    success: false,
    message: defaultMessage,
  });
}

// ==========================================
// GET ALL DAMAGED ITEMS
// ==========================================

export const getAllDamagedItems = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const ownerId = getOwnerId(req);

    if (ownerId === null) {
      res.status(403).json({
        success: false,
        message: "Akses inventaris tidak ditemukan.",
      });
      return;
    }

    const damagedItems =
      await damagedItemService.getAll(ownerId);

    res.status(200).json({
      success: true,
      data: damagedItems,
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal mengambil riwayat barang rusak."
    );
  }
};

// ==========================================
// CREATE DAMAGED ITEM
// ==========================================

export const createDamagedItem = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const ownerId = getOwnerId(req);

    if (ownerId === null) {
      res.status(403).json({
        success: false,
        message: "Akses inventaris tidak ditemukan.",
      });
      return;
    }

    const input = createDamagedItemSchema.parse(req.body);

    const damagedItem = await damagedItemService.create(
      ownerId,
      input
    );

    res.status(201).json({
      success: true,
      message: "Laporan barang rusak berhasil ditambahkan.",
      data: damagedItem,
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal menyimpan laporan barang rusak."
    );
  }
};

// ==========================================
// UPDATE DAMAGED ITEM STATUS
// ==========================================

export const updateDamagedItemStatus = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const ownerId = getOwnerId(req);

    if (ownerId === null) {
      res.status(403).json({
        success: false,
        message: "Akses inventaris tidak ditemukan.",
      });
      return;
    }

    const { id } = damagedItemIdSchema.parse(req.params);

    const input = updateDamagedItemStatusSchema.parse(
      req.body
    );

    await damagedItemService.updateStatus(
      req.userId,
      ownerId,
      req.teamRole,
      id,
      input
    );

    res.status(200).json({
      success: true,
      message:
        input.status === "Disetujui"
          ? "Laporan berhasil disetujui."
          : "Laporan berhasil ditolak.",
      data: {
        id,
        status: input.status,
      },
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal memperbarui status laporan."
    );
  }
};
