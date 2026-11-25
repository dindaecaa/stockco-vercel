
import { Router } from "express";

import {
  getAllCategories,
  createCategory,
  updateCategory,
  deleteCategory,
  
} from "../controllers/categoryController.js";

import { authMiddleware } from "../middleware/authMiddleware.js";
import { inventoryAccessMiddleware } from "../middleware/inventoryAccessMiddleware.js";

const router = Router();

// Semua anggota toko dapat melihat kategori.
router.get(
  "/",
  authMiddleware,
  inventoryAccessMiddleware,
  getAllCategories
);

// Pengelolaan kategori hanya untuk Owner ID 8.
// Validasi hak akses dilakukan di categoryController.
router.post("/", authMiddleware, createCategory);
router.put("/:id", authMiddleware, updateCategory);
router.delete("/:id", authMiddleware, deleteCategory);

export default router;
