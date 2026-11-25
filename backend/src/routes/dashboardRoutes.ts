
import { Router } from "express";

import {
  getDashboard,
  getDashboardMonthlyChartController,
  getDashboardCategoryChartController,
  getDashboardStockAlertsController,
} from "../controllers/dashboardController";

import { authMiddleware } from "../middleware/authMiddleware";
import { inventoryAccessMiddleware } from "../middleware/inventoryAccessMiddleware";

const router = Router();

// ==========================================
// DASHBOARD ACCESS
// ==========================================

router.use(authMiddleware);
router.use(inventoryAccessMiddleware);

// ==========================================
// DASHBOARD SUMMARY
// ==========================================

router.get("/", getDashboard);

// ==========================================
// DASHBOARD STOCK ALERTS
// ==========================================

router.get(
  "/stock-alerts",
  getDashboardStockAlertsController
);

// ==========================================
// DASHBOARD MONTHLY STOCK MOVEMENTS
// ==========================================

router.get(
  "/stock-movements",
  getDashboardMonthlyChartController
);

// ==========================================
// DASHBOARD CATEGORY SUMMARY
// ==========================================

router.get(
  "/categories",
  getDashboardCategoryChartController
);

export default router;
