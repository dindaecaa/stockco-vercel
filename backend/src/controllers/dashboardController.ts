
import type { Request, Response } from "express";

import {
  getDashboardData,
  getDashboardMonthlyChart,
  getDashboardCategoryChart,
  getDashboardStockAlerts,
  DashboardError,
} from "../services/dashboardService";

// ==========================================
// GET DASHBOARD SUMMARY
// ==========================================

export const getDashboard = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const data = await getDashboardData(req.ownerId);

    res.status(200).json({
      success: true,
      data,
    });
  } catch (error: unknown) {
    if (error instanceof DashboardError) {
      res.status(error.statusCode).json({
        success: false,
        message: error.message,
      });
      return;
    }

    console.error("Get dashboard error:", error);

    res.status(500).json({
      success: false,
      message: "Gagal mengambil data dashboard.",
    });
  }
};

// ==========================================
// GET DASHBOARD STOCK ALERTS
// ==========================================

export const getDashboardStockAlertsController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const data = await getDashboardStockAlerts(req.ownerId);

    res.status(200).json({
      success: true,
      data,
    });
  } catch (error: unknown) {
    if (error instanceof DashboardError) {
      res.status(error.statusCode).json({
        success: false,
        message: error.message,
      });
      return;
    }

    console.error("Get dashboard stock alerts error:", error);

    res.status(500).json({
      success: false,
      message: "Gagal mengambil notifikasi stok.",
    });
  }
};

// ==========================================
// GET DASHBOARD MONTHLY CHART
// ==========================================

export const getDashboardMonthlyChartController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const periodParam = req.query.period;

    const period =
      typeof periodParam === "string" && periodParam.trim() !== ""
        ? Number(periodParam)
        : 3;

    const data = await getDashboardMonthlyChart(
      req.ownerId,
      period
    );

    res.status(200).json({
      success: true,
      data,
    });
  } catch (error: unknown) {
    if (error instanceof DashboardError) {
      res.status(error.statusCode).json({
        success: false,
        message: error.message,
      });
      return;
    }

    console.error("Get dashboard monthly chart error:", error);

    res.status(500).json({
      success: false,
      message: "Gagal mengambil data grafik dashboard.",
    });
  }
};

// ==========================================
// GET DASHBOARD CATEGORY CHART
// ==========================================

export const getDashboardCategoryChartController = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const data = await getDashboardCategoryChart(req.ownerId);

    res.status(200).json({
      success: true,
      data,
    });
  } catch (error: unknown) {
    if (error instanceof DashboardError) {
      res.status(error.statusCode).json({
        success: false,
        message: error.message,
      });
      return;
    }

    console.error("Get dashboard category chart error:", error);

    res.status(500).json({
      success: false,
      message: "Gagal mengambil data kategori dashboard.",
    });
  }
};
