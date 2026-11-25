
import { Router } from "express";

import {
  getStockNotifications,
} from "../controllers/aiStockController";

import { authMiddleware } from "../middleware/authMiddleware";
import { inventoryAccessMiddleware } from "../middleware/inventoryAccessMiddleware";

const router = Router();

router.use(authMiddleware);
router.use(inventoryAccessMiddleware);

router.get("/notifications", getStockNotifications);

export default router;
