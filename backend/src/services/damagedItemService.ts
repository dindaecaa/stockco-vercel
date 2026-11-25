
import {
  damagedItemRepository,
  type DamagedItemRow,
} from "../repositories/damagedItemRepository";

import type {
  CreateDamagedItemDto,
  UpdateDamagedItemStatusDto,
  DamagedItemDto,
  CreatedDamagedItemDto,
} from "../dto/damagedItemDto";

const OWNER_ACCOUNT_ID = 8;

export class DamagedItemServiceError extends Error {
  constructor(
    message: string,
    public statusCode: number
  ) {
    super(message);
    this.name = "DamagedItemServiceError";
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

function ensureOwner(
  userId: number | undefined,
  ownerId: number,
  teamRole: string | undefined
): void {
  if (
    userId !== OWNER_ACCOUNT_ID ||
    ownerId !== OWNER_ACCOUNT_ID ||
    teamRole !== "owner"
  ) {
    throw new DamagedItemServiceError(
      "Hanya Owner yang dapat menyetujui atau menolak laporan.",
      403
    );
  }
}

export const damagedItemService = {
  async getAll(ownerId: number): Promise<DamagedItemDto[]> {
    const items: DamagedItemRow[] =
      await damagedItemRepository.findAll(ownerId);

    return items;
  },

  async create(
    ownerId: number,
    input: CreateDamagedItemDto
  ): Promise<CreatedDamagedItemDto> {
    const sku = input.product_sku.trim();

    const product =
      await damagedItemRepository.findProductBySku(
        sku,
        ownerId
      );

    if (!product) {
      throw new DamagedItemServiceError(
        "Barang tidak ditemukan pada inventaris Anda.",
        404
      );
    }

    const finalLocation =
      normalizeOptionalString(input.location) ??
      product.location;

    const finalNote = normalizeOptionalString(input.note);

    const finalPhotoKey = normalizeOptionalString(
      input.photo_key
    );

    const quantity = input.quantity;
    const reason = input.reason.trim();

    const id = await damagedItemRepository.create(
      ownerId,
      {
        productId: product.id,
        productName: product.name,
        productSku: product.sku,
        location: finalLocation,
        quantity,
        reason,
        note: finalNote,
        photoKey: finalPhotoKey,
      }
    );

    return {
      id,
      product_id: product.id,
      product_name: product.name,
      product_sku: product.sku,
      location: finalLocation,
      quantity,
      reason,
      note: finalNote,
      status: "Belum ditindaklanjuti",
      photo_key: finalPhotoKey,
    };
  },

  async updateStatus(
    userId: number | undefined,
    ownerId: number,
    teamRole: string | undefined,
    reportId: number,
    input: UpdateDamagedItemStatusDto
  ): Promise<void> {
    ensureOwner(userId, ownerId, teamRole);

    const updated =
      await damagedItemRepository.updatePendingStatus(
        reportId,
        ownerId,
        input.status
      );

    if (!updated) {
      throw new DamagedItemServiceError(
        "Laporan tidak ditemukan atau sudah ditindaklanjuti.",
        404
      );
    }
  },
};
