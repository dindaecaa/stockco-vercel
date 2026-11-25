
import { Router } from "express";

import {
  getAllStockMovements,
  getTodayStockIns,
  createStockMovement,
} from "../controllers/stockMovementController";

import { authMiddleware } from "../middleware/authMiddleware";
import { inventoryAccessMiddleware } from "../middleware/inventoryAccessMiddleware";

const router = Router();

router.use(authMiddleware);
router.use(inventoryAccessMiddleware);

router.get("/today", getTodayStockIns);
router.get("/", getAllStockMovements);
router.post("/", createStockMovement);

export default router;
