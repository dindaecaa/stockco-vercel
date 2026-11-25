
import type { Request, Response } from "express";
import { ZodError } from "zod";

import {
  supplierIdSchema,
  createSupplierSchema,
  updateSupplierSchema,
} from "../validators/supplierValidator";

import {
  supplierService,
  SupplierServiceError,
} from "../services/supplierService";

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
  if (error instanceof SupplierServiceError) {
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
        "Data supplier tidak valid.",
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
// GET ALL SUPPLIERS
// ==========================================

export const getSuppliers = async (
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

    const suppliers = await supplierService.getAll(ownerId);

    res.status(200).json({
      success: true,
      data: suppliers,
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal mengambil data supplier."
    );
  }
};

// ==========================================
// CREATE SUPPLIER
// ==========================================

export const createSupplier = async (
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

    const input = createSupplierSchema.parse(req.body);

    const supplierId = await supplierService.create(
      ownerId,
      input
    );

    res.status(201).json({
      success: true,
      message: "Supplier berhasil ditambahkan.",
      supplierId,
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal menambahkan supplier."
    );
  }
};

// ==========================================
// UPDATE SUPPLIER
// ==========================================

export const updateSupplier = async (
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

    const { id } = supplierIdSchema.parse(req.params);
    const input = updateSupplierSchema.parse(req.body);

    await supplierService.update(id, ownerId, input);

    res.status(200).json({
      success: true,
      message: "Supplier berhasil diperbarui.",
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal memperbarui supplier."
    );
  }
};

// ==========================================
// DELETE SUPPLIER
// ==========================================

export const deleteSupplier = async (
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

    const { id } = supplierIdSchema.parse(req.params);

    await supplierService.delete(id, ownerId);

    res.status(200).json({
      success: true,
      message: "Supplier berhasil dihapus.",
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal menghapus supplier. Supplier mungkin masih digunakan dalam riwayat transaksi."
    );
  }
};
