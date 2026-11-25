
import type { Request, Response } from "express";

import {
  createStockMovementSchema,
} from "../validators/stockMovementValidator";

import {
  createStockMovement as createStockMovementService,
  getAllStockMovements as getAllStockMovementsService,
  getTodayStockIns as getTodayStockInsService,
  StockMovementError,
} from "../services/stockMovementService";

function handleError(res: Response, error: unknown) {
  if (error instanceof StockMovementError) {
    return res.status(error.statusCode).json({
      success: false,
      message: error.message,
    });
  }

  console.error("Stock Movement Controller Error:", error);

  return res.status(500).json({
    success: false,
    message: "Terjadi kesalahan pada server.",
  });
}

export async function getAllStockMovements(
  req: Request,
  res: Response
) {
  try {
    const rows = await getAllStockMovementsService(req.ownerId);

    return res.status(200).json({
      success: true,
      message: "Riwayat pergerakan stok berhasil diambil.",
      data: rows,
    });
  } catch (error) {
    return handleError(res, error);
  }
}

export async function getTodayStockIns(
  req: Request,
  res: Response
) {
  try {
    const rows = await getTodayStockInsService(req.ownerId);

    return res.status(200).json({
      success: true,
      message: "Penerimaan hari ini berhasil diambil.",
      data: rows,
    });
  } catch (error) {
    return handleError(res, error);
  }
}

export async function createStockMovement(
  req: Request,
  res: Response
) {
  const validation = createStockMovementSchema.safeParse(req.body);

  if (!validation.success) {
    return res.status(400).json({
      success: false,
      message:
        validation.error.issues[0]?.message ??
        "Data transaksi stok tidak valid.",
    });
  }

  try {
    const result = await createStockMovementService(
      req.ownerId,
      req.userId,
      validation.data
    );

    return res.status(201).json({
      success: true,
      message:
        result.type === "in"
          ? "Stok masuk berhasil disimpan."
          : "Stok keluar berhasil disimpan.",
      data: result,
    });
  } catch (error) {
    return handleError(res, error);
  }
}
