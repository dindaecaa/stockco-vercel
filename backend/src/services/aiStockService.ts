
import { findStockAlerts } from "../repositories/aiStockRepository";

import type {
  AIStockDto,
  StockNotificationDto,
} from "../dto/aiStockDto";

export class AIStockError extends Error {
  statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.name = "AIStockError";
    this.statusCode = statusCode;
  }
}

function validateOwnerId(ownerId: number | undefined): number {
  if (
    typeof ownerId !== "number" ||
    !Number.isSafeInteger(ownerId) ||
    ownerId <= 0
  ) {
    throw new AIStockError(
      "Akses inventaris tidak ditemukan.",
      403
    );
  }

  return ownerId;
}

export async function getStockNotifications(
  ownerId: number | undefined
): Promise<AIStockDto> {
  const validOwnerId = validateOwnerId(ownerId);

  const rows = await findStockAlerts(validOwnerId);

  const notifications: StockNotificationDto[] = rows.map(
    (product) => {
      const stock = Number(product.stock);
      const minimumStock = Number(product.minimum_stock);

      const isOutOfStock = stock <= 0;

      return {
        id: product.id,
        name: product.name,
        sku: product.sku,
        stock,
        minimum_stock: minimumStock,
        unit: product.unit,
        location: product.location,
        status: isOutOfStock ? "habis" : "menipis",
        message: isOutOfStock
          ? `${product.name} sudah habis dan perlu segera di-restock.`
          : `${product.name} memiliki stok ${stock} ${product.unit ?? "pcs"} dan perlu segera di-restock.`,
      };
    }
  );

  const outOfStockCount = notifications.filter(
    (item) => item.status === "habis"
  ).length;

  const lowStockCount = notifications.filter(
    (item) => item.status === "menipis"
  ).length;

  const result: AIStockDto = {
    total_alerts: notifications.length,
    out_of_stock_count: outOfStockCount,
    low_stock_count: lowStockCount,
    notifications,
    recommendation:
      notifications.length === 0
        ? "Semua stok barang dalam kondisi aman."
        : `Terdapat ${outOfStockCount} barang habis dan ${lowStockCount} barang menipis. Segera periksa dan lakukan restock.`,
  };

  return result;
}
