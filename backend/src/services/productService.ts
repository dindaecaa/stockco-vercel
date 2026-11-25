import { productRepository } from "../repositories/productRepository";
import { supplierRepository } from "../repositories/supplierRepository";

import type {
  CreateProductDto,
  UpdateProductDto,
  ProductDto,
} from "../dto/productDto";

export class ProductServiceError extends Error {
  constructor(
    message: string,
    public statusCode: number
  ) {
    super(message);
    this.name = "ProductServiceError";
  }
}

// ==========================================
// VALIDATE SUPPLIER OWNERSHIP
// ==========================================

async function validateSupplier(
  supplierId: number | null,
  ownerId: number
) {
  if (supplierId === null) {
    return null;
  }

  const supplier = await supplierRepository.findById(
    supplierId,
    ownerId
  );

  if (!supplier) {
    throw new ProductServiceError(
      "Pemasok tidak ditemukan atau bukan milik akun Anda.",
      400
    );
  }

  return supplier;
}

// ==========================================
// PRODUCT SERVICE
// ==========================================

export const productService = {
  // ----------------------------------------
  // GET ALL PRODUCTS
  // ----------------------------------------

  async getAll(ownerId: number): Promise<ProductDto[]> {
    return productRepository.findAll(ownerId);
  },

  // ----------------------------------------
  // GET PRODUCT BY ID
  // ----------------------------------------

  async getById(
    id: number,
    ownerId: number
  ): Promise<ProductDto> {
    const product = await productRepository.findById(
      id,
      ownerId
    );

    if (!product) {
      throw new ProductServiceError(
        "Produk tidak ditemukan.",
        404
      );
    }

    return product;
  },

  // ----------------------------------------
  // CREATE PRODUCT
  // ----------------------------------------

  async create(
    ownerId: number,
    input: CreateProductDto
  ): Promise<ProductDto> {
    let categoryId = input.category_id ?? null;

    // VALIDATE CATEGORY NAME
    if (input.category) {
      const category =
        await productRepository.findCategoryByName(
          input.category
        );

      if (!category) {
        throw new ProductServiceError(
          "Kategori tidak ditemukan. Silakan minta Owner menambahkan kategori terlebih dahulu.",
          400
        );
      }

      if (
        categoryId !== null &&
        categoryId !== category.id
      ) {
        throw new ProductServiceError(
          "Nama kategori dan ID kategori tidak cocok.",
          400
        );
      }

      categoryId = category.id;
    }

    // VALIDATE CATEGORY ID
    if (categoryId !== null) {
      const category =
        await productRepository.findCategoryById(
          categoryId
        );

      if (!category) {
        throw new ProductServiceError(
          "Kategori tidak ditemukan.",
          400
        );
      }
    }

    // VALIDATE SUPPLIER
    const supplierId = input.supplier_id ?? null;

    const supplier = await validateSupplier(
      supplierId,
      ownerId
    );

    // PRODUCT DATA
    const sku =
      input.sku?.trim() || `SKU-${Date.now()}`;

    const resellerName =
      input.reseller_name?.trim() || null;

    const description =
      input.description?.trim() || null;

    const minimumStock =
      input.minimum_stock ?? 5;

    const unit =
      input.unit?.trim() || "pcs";

    const price =
      input.price ?? 0;

    const location =
      input.location?.trim() || null;

    try {
      return await productRepository.withTransaction(
        async (connection): Promise<ProductDto> => {
          const id = await productRepository.create(
            ownerId,
            {
              categoryId,
              supplierId,
              name: input.name,
              resellerName,
              sku,
              description,
              stock: input.stock,
              minimumStock,
              unit,
              price,
              location,
            },
            connection
          );

          return {
            id,
            owner_id: ownerId,
            category_id: categoryId,
            category_name: input.category ?? null,
            supplier_id: supplierId,
            supplier_name: supplier?.name ?? null,
            name: input.name,
            reseller_name: resellerName,
            sku,
            description,
            stock: input.stock,
            minimum_stock: minimumStock,
            unit,
            price,
            location,
          };
        }
      );
    } catch (error) {
      if (
        typeof error === "object" &&
        error !== null &&
        "code" in error &&
        error.code === "ER_DUP_ENTRY"
      ) {
        throw new ProductServiceError(
          "SKU sudah digunakan. Gunakan SKU lain.",
          409
        );
      }

      throw error;
    }
  },

  // ----------------------------------------
  // UPDATE PRODUCT
  // ----------------------------------------

  async update(
    id: number,
    ownerId: number,
    input: UpdateProductDto
  ): Promise<ProductDto> {
    const existing = await productRepository.findById(
      id,
      ownerId
    );

    if (!existing) {
      throw new ProductServiceError(
        "Produk tidak ditemukan.",
        404
      );
    }

    // CATEGORY
    let categoryId = existing.category_id;

    if (input.category !== undefined) {
      if (
        input.category === null ||
        input.category.trim() === ""
      ) {
        categoryId = null;
      } else {
        const category =
          await productRepository.findCategoryByName(
            input.category
          );

        if (!category) {
          throw new ProductServiceError(
            "Kategori tidak ditemukan.",
            400
          );
        }

        categoryId = category.id;
      }
    }

    if (input.category_id !== undefined) {
      const requestedCategoryId =
        input.category_id === null ||
        input.category_id === ""
          ? null
          : Number(input.category_id);

      if (
        input.category !== undefined &&
        requestedCategoryId !== categoryId
      ) {
        throw new ProductServiceError(
          "Nama kategori dan ID kategori tidak cocok.",
          400
        );
      }

      categoryId = requestedCategoryId;
    }

    if (categoryId !== null) {
      const category =
        await productRepository.findCategoryById(
          categoryId
        );

      if (!category) {
        throw new ProductServiceError(
          "Kategori tidak ditemukan.",
          400
        );
      }
    }

    // SUPPLIER
    const supplierId =
      input.supplier_id === undefined
        ? existing.supplier_id
        : input.supplier_id;

    const supplier = await validateSupplier(
      supplierId,
      ownerId
    );

    // OTHER PRODUCT DATA
    const resellerName =
      input.reseller_name === undefined
        ? existing.reseller_name
        : input.reseller_name?.trim() || null;

    const sku =
      input.sku === undefined
        ? existing.sku
        : input.sku?.trim() || null;

    const description =
      input.description === undefined
        ? existing.description
        : input.description?.trim() || null;

    const minimumStock =
      input.minimum_stock ?? existing.minimum_stock;

    const unit =
      input.unit === undefined
        ? existing.unit
        : input.unit?.trim() || null;

    const location =
      input.location === undefined
        ? existing.location
        : input.location?.trim() || null;

    const price = input.price;

    await productRepository.update(
      id,
      ownerId,
      {
        categoryId,
        supplierId,
        name: input.name,
        resellerName,
        sku,
        description,
        stock: input.stock,
        minimumStock,
        unit,
        price,
        location,
      }
    );

    return {
      ...existing,
      category_id: categoryId,
      supplier_id: supplierId,
      supplier_name: supplier?.name ?? null,
      name: input.name,
      reseller_name: resellerName,
      sku,
      description,
      stock: input.stock,
      minimum_stock: minimumStock,
      unit,
      price,
      location,
    };
  },

  // ----------------------------------------
  // DELETE PRODUCT
  // ----------------------------------------

  async delete(
    id: number,
    ownerId: number
  ): Promise<void> {
    const deleted = await productRepository.delete(
      id,
      ownerId
    );

    if (!deleted) {
      throw new ProductServiceError(
        "Produk tidak ditemukan.",
        404
      );
    }
  },
};