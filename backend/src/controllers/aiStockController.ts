
import type { Request, Response } from "express";

import {
  getStockNotifications as getStockNotificationsService,
  AIStockError,
} from "../services/aiStockService";

export const getStockNotifications = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const data = await getStockNotificationsService(req.ownerId);

    res.status(200).json({
      success: true,
      message: "Analisis stok berhasil dilakukan.",
      data,
    });
  } catch (error: unknown) {
    if (error instanceof AIStockError) {
      res.status(error.statusCode).json({
        success: false,
        message: error.message,
      });
      return;
    }

    console.error("AI stock notification error:", error);

    res.status(500).json({
      success: false,
      message: "Gagal menganalisis data stok.",
    });
  }
};
