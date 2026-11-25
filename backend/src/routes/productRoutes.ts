import { Router } from "express";

import {
  getAllProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct,
} from "../controllers/productController.js";

import { authMiddleware } from "../middleware/authMiddleware";
import { inventoryAccessMiddleware } from "../middleware/inventoryAccessMiddleware";

const router = Router();

router.use(authMiddleware);
router.use(inventoryAccessMiddleware);

router.get("/", getAllProducts);
router.get("/:id", getProductById);
router.post("/", createProduct);
router.put("/:id", updateProduct);
router.delete("/:id", deleteProduct);

export default router;
