import { Router } from "express";

import {
  getBranches,
  createBranchController,
  deleteBranchController,
} from "../controllers/branchController";

import { authMiddleware } from "../middleware/authMiddleware";
import { inventoryAccessMiddleware } from "../middleware/inventoryAccessMiddleware";

const router = Router();

// Semua endpoint wajib login dan memiliki akses inventaris.
router.use(authMiddleware);
router.use(inventoryAccessMiddleware);

// Owner, Admin, Leader, Staff: boleh melihat cabang.
router.get("/", getBranches);

// Owner dan Admin: boleh menambah cabang.
router.post("/", createBranchController);

// Owner dan Admin: boleh menghapus cabang.
router.delete("/:id", deleteBranchController);

export default router;