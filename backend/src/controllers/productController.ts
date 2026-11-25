
import type { Request, Response } from "express";
import { ZodError } from "zod";
import {
  createProductSchema,
  productIdSchema,
  updateProductSchema,
} from "../validators/productValidator";
import {
  productService,
  ProductServiceError,
} from "../services/productService";

function getOwnerId(req: Request): number | null {
  return typeof req.ownerId === "number" ? req.ownerId : null;
}

function handleError(
  res: Response,
  error: unknown,
  defaultMessage: string
): void {
  if (error instanceof ProductServiceError) {
    res.status(error.statusCode).json({
      success: false,
      message: error.message,
    });
    return;
  }

  if (error instanceof ZodError) {
    res.status(400).json({
      success: false,
      message: error.issues[0]?.message || "Data tidak valid.",
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

export const getAllProducts = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const ownerId = getOwnerId(req);

    if (ownerId === null) {
      res.status(403).json({
        success: false,
        message: "Akses inventaris tidak ditemukan.",
      });
      return;
    }

    const products = await productService.getAll(ownerId);

    res.status(200).json({
      success: true,
      message: "Data produk berhasil diambil.",
      data: products,
    });
  } catch (error) {
    handleError(res, error, "Gagal mengambil data produk.");
  }
};

export const getProductById = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const ownerId = getOwnerId(req);

    if (ownerId === null) {
      res.status(403).json({
        success: false,
        message: "Akses inventaris tidak ditemukan.",
      });
      return;
    }

    const { id } = productIdSchema.parse(req.params);
    const product = await productService.getById(id, ownerId);

    res.status(200).json({
      success: true,
      data: product,
    });
  } catch (error) {
    handleError(res, error, "Gagal mengambil detail produk.");
  }
};

export const createProduct = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const ownerId = getOwnerId(req);

    if (ownerId === null) {
      res.status(403).json({
        success: false,
        message: "Akses inventaris tidak ditemukan.",
      });
      return;
    }

    const input = createProductSchema.parse(req.body);
    const product = await productService.create(ownerId, input);

    res.status(201).json({
      success: true,
      message: "Produk berhasil ditambahkan.",
      data: product,
    });
  } catch (error) {
    handleError(res, error, "Gagal menambahkan produk.");
  }
};

export const updateProduct = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const ownerId = getOwnerId(req);

    if (ownerId === null) {
      res.status(403).json({
        success: false,
        message: "Akses inventaris tidak ditemukan.",
      });
      return;
    }

    const { id } = productIdSchema.parse(req.params);
    const input = updateProductSchema.parse(req.body);
    const product = await productService.update(id, ownerId, input);

    res.status(200).json({
      success: true,
      message: "Produk berhasil diperbarui.",
      data: product,
    });
  } catch (error) {
    handleError(res, error, "Gagal memperbarui produk.");
  }
};

export const deleteProduct = async (
  req: Request,
  res: Response
): Promise<void> => {
  try {
    const ownerId = getOwnerId(req);

    if (ownerId === null) {
      res.status(403).json({
        success: false,
        message: "Akses inventaris tidak ditemukan.",
      });
      return;
    }

    const { id } = productIdSchema.parse(req.params);
    await productService.delete(id, ownerId);

    res.status(200).json({
      success: true,
      message: "Produk berhasil dihapus.",
    });
  } catch (error) {
    handleError(
      res,
      error,
      "Gagal menghapus produk. Produk mungkin masih memiliki riwayat transaksi."
    );
  }
};
