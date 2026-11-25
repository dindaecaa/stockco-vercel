
import {
  categoryRepository,
} from "../repositories/categoryRepository";

import type {
  CreateCategoryDto,
  UpdateCategoryDto,
  CategoryDto,
} from "../dto/categoryDto";

const OWNER_ACCOUNT_ID = 8;

export class CategoryServiceError extends Error {
  constructor(
    message: string,
    public statusCode: number
  ) {
    super(message);
    this.name = "CategoryServiceError";
  }
}

function ensureOwner(userId: number | undefined): void {
  if (userId !== OWNER_ACCOUNT_ID) {
    throw new CategoryServiceError(
      "Hanya Owner yang dapat mengelola kategori.",
      403
    );
  }
}

function normalizeDescription(
  description: string | null | undefined
): string | null {
  return description?.trim() || null;
}

export const categoryService = {
  async getAll(ownerId: number): Promise<CategoryDto[]> {
    return categoryRepository.findAll(ownerId);
  },

  async create(
    userId: number | undefined,
    input: CreateCategoryDto
  ): Promise<CategoryDto> {
    ensureOwner(userId);

    const name = input.name.trim();
    const description = normalizeDescription(input.description);

    const duplicate = await categoryRepository.findDuplicateName(
      name
    );

    if (duplicate) {
      throw new CategoryServiceError(
        "Nama kategori sudah digunakan.",
        409
      );
    }

    const id = await categoryRepository.create(
      name,
      description
    );

    return {
      id,
      name,
      description,
      item_count: 0,
    };
  },

  async update(
    userId: number | undefined,
    id: number,
    input: UpdateCategoryDto
  ): Promise<void> {
    ensureOwner(userId);

    const category = await categoryRepository.findById(id);

    if (!category) {
      throw new CategoryServiceError(
        "Kategori tidak ditemukan.",
        404
      );
    }

    const name = input.name.trim();
    const description = normalizeDescription(input.description);

    const duplicate = await categoryRepository.findDuplicateName(
      name,
      id
    );

    if (duplicate) {
      throw new CategoryServiceError(
        "Nama kategori sudah digunakan.",
        409
      );
    }

    await categoryRepository.update(
      id,
      name,
      description
    );
  },

  async delete(
    userId: number | undefined,
    id: number
  ): Promise<void> {
    ensureOwner(userId);

    const category = await categoryRepository.findById(id);

    if (!category) {
      throw new CategoryServiceError(
        "Kategori tidak ditemukan.",
        404
      );
    }

    const productCount = await categoryRepository.countProducts(id);

    if (productCount > 0) {
      throw new CategoryServiceError(
        "Kategori tidak dapat dihapus karena masih digunakan oleh produk.",
        409
      );
    }

    await categoryRepository.delete(id);
  },
};
