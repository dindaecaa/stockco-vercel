
import type { Request, Response } from "express";
import { ZodError } from "zod";

import {
  categoryIdSchema,
  createCategorySchema,
  updateCategorySchema,
} from "../validators/categoryValidator";

import {
  categoryService,
  CategoryServiceError,
} from "../services/categoryService";

function handleError(
  res: Response,
  error: unknown,
  defaultMessage: string
): void {
  if (error instanceof CategoryServiceError) {
    res.status(error.statusCode).json({
      success: false,
      message: error.message,
    });
    return;
  }

  if (error instanceof ZodError) {
    res.status(400).json({
      success: false,
      message:
        error.issues[0]?.message || "Data kategori tidak valid.",
      errors: error.issues,
    });
    return;
  }

  console.error(defaultMessage, error);

  res.status(500).json({
    success: false,
    message: defaultMessage,
  });
}

// GET ALL CATEGORIES
export const getAllCategories = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const ownerId = req.ownerId;

    if (typeof ownerId !== "number") {
      res.status(403).json({
        success: false,
        message: "Akses inventaris tidak ditemukan.",
      });
      return;
    }

    const categories = await categoryService.getAll(ownerId);

    res.status(200).json({
      success: true,
      data: categories,
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal mengambil data kategori."
    );
  }
};

// CREATE CATEGORY
export const createCategory = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const input = createCategorySchema.parse(req.body);

    const category = await categoryService.create(
      req.userId,
      input
    );

    res.status(201).json({
      success: true,
      message: "Kategori berhasil ditambahkan.",
      data: category,
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal menambahkan kategori."
    );
  }
};

// UPDATE CATEGORY
export const updateCategory = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const { id } = categoryIdSchema.parse(req.params);
    const input = updateCategorySchema.parse(req.body);

    await categoryService.update(req.userId, id, input);

    res.status(200).json({
      success: true,
      message: "Kategori berhasil diperbarui.",
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal memperbarui kategori."
    );
  }
};

// DELETE CATEGORY
export const deleteCategory = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const { id } = categoryIdSchema.parse(req.params);

    await categoryService.delete(req.userId, id);

    res.status(200).json({
      success: true,
      message: "Kategori berhasil dihapus.",
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal menghapus kategori."
    );
  }
};
