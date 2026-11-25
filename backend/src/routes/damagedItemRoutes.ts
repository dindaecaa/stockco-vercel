
import { Router } from "express";

import {
  getAllDamagedItems,
  createDamagedItem,
  updateDamagedItemStatus,
} from "../controllers/damagedItemController.js";

import { authMiddleware } from "../middleware/authMiddleware";
import { inventoryAccessMiddleware } from "../middleware/inventoryAccessMiddleware";

const router = Router();

router.use(authMiddleware);
router.use(inventoryAccessMiddleware);

router.get("/", getAllDamagedItems);
router.post("/", createDamagedItem);
router.patch("/:id/status", updateDamagedItemStatus);

export default router;
