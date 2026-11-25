
import {
  supplierRepository,
  type SupplierRow,
} from "../repositories/supplierRepository";

import type {
  CreateSupplierInput,
  UpdateSupplierInput,
} from "../validators/supplierValidator";

export class SupplierServiceError extends Error {
  constructor(
    message: string,
    public statusCode: number
  ) {
    super(message);
    this.name = "SupplierServiceError";
  }
}

function normalizeOptionalString(
  value: string | null | undefined
): string | null {
  if (value === undefined || value === null) {
    return null;
  }

  return value.trim() || null;
}

export const supplierService = {
  async getAll(ownerId: number): Promise<SupplierRow[]> {
    return supplierRepository.findAll(ownerId);
  },

  async create(
    ownerId: number,
    input: CreateSupplierInput
  ): Promise<number> {
    return supplierRepository.create(ownerId, {
      name: input.name.trim(),
      phone: normalizeOptionalString(input.phone),
      email: normalizeOptionalString(input.email),
      address: normalizeOptionalString(input.address),
    });
  },

  async update(
    id: number,
    ownerId: number,
    input: UpdateSupplierInput
  ): Promise<void> {
    const existing = await supplierRepository.findById(
      id,
      ownerId
    );

    if (!existing) {
      throw new SupplierServiceError(
        "Supplier tidak ditemukan.",
        404
      );
    }

    const updated = await supplierRepository.update(
      id,
      ownerId,
      {
        name: input.name.trim(),
        phone:
          input.phone === undefined
            ? existing.phone
            : normalizeOptionalString(input.phone),
        email:
          input.email === undefined
            ? existing.email
            : normalizeOptionalString(input.email),
        address:
          input.address === undefined
            ? existing.address
            : normalizeOptionalString(input.address),
      }
    );

    if (!updated) {
      throw new SupplierServiceError(
        "Supplier tidak ditemukan.",
        404
      );
    }
  },

  async delete(
    id: number,
    ownerId: number
  ): Promise<void> {
    const deleted = await supplierRepository.delete(
      id,
      ownerId
    );

    if (!deleted) {
      throw new SupplierServiceError(
        "Supplier tidak ditemukan.",
        404
      );
    }
  },
};
