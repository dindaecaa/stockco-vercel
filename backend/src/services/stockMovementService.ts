
import type { PoolConnection } from "mysql2/promise";

import pool from "../db";

import {
  findAllStockMovements,
  findTodayStockIns,
  findProductForUpdate,
  findSupplierById,
  insertStockMovement,
  updateProductStock,
  type TodayReceivingRow,
} from "../repositories/stockMovementRepository";

import type {
  CreateStockMovementDto,
  StockMovementDto,
  StockMovementInsertDto,
  CreatedStockMovementDto,
} from "../dto/stockMovementDto";

class StockMovementError extends Error {
  statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.name = "StockMovementError";
    this.statusCode = statusCode;
  }
}

function validateUserContext(
  ownerId: number | undefined,
  userId?: number
): { ownerId: number; userId?: number } {
  if (
    typeof ownerId !== "number" ||
    !Number.isSafeInteger(ownerId) ||
    ownerId <= 0
  ) {
    throw new StockMovementError(
      "Informasi pemilik inventaris tidak valid.",
      401
    );
  }

  if (
    userId !== undefined &&
    (!Number.isSafeInteger(userId) || userId <= 0)
  ) {
    throw new StockMovementError(
      "Informasi pengguna tidak valid.",
      401
    );
  }

  return { ownerId, userId };
}

export async function getAllStockMovements(
  ownerId: number | undefined
): Promise<StockMovementDto[]> {
  const context = validateUserContext(ownerId);

  return findAllStockMovements(context.ownerId);
}

export async function getTodayStockIns(
  ownerId: number | undefined
): Promise<TodayReceivingRow[]> {
  const context = validateUserContext(ownerId);

  return findTodayStockIns(context.ownerId);
}

export async function createStockMovement(
  ownerId: number | undefined,
  userId: number | undefined,
  input: CreateStockMovementDto
): Promise<CreatedStockMovementDto> {
  const context = validateUserContext(ownerId, userId);

  if (context.userId === undefined) {
    throw new StockMovementError(
      "Informasi pengguna tidak ditemukan.",
      401
    );
  }

  let connection: PoolConnection | undefined;
  let transactionStarted = false;

  try {
    connection = await pool.getConnection();

    await connection.beginTransaction();
    transactionStarted = true;

    const product = await findProductForUpdate(
      connection,
      input.product_id,
      context.ownerId
    );

    if (!product) {
      throw new StockMovementError(
        "Produk tidak ditemukan.",
        404
      );
    }

    const currentStock = Number(product.stock);

    if (
      !Number.isSafeInteger(currentStock) ||
      currentStock < 0
    ) {
      throw new StockMovementError(
        "Data stok produk tidak valid.",
        500
      );
    }

    if (
      input.supplier_id !== undefined &&
      input.supplier_id !== null
    ) {
      const supplier = await findSupplierById(
        connection,
        input.supplier_id,
        context.ownerId
      );

      if (!supplier) {
        throw new StockMovementError(
          "Supplier tidak ditemukan.",
          404
        );
      }
    }

    if (
      input.type === "out" &&
      input.quantity > currentStock
    ) {
      throw new StockMovementError(
        `Stok tidak mencukupi. Stok tersedia: ${currentStock}.`,
        400
      );
    }

    const newStock =
      input.type === "in"
        ? currentStock + input.quantity
        : currentStock - input.quantity;

    if (!Number.isSafeInteger(newStock) || newStock < 0) {
      throw new StockMovementError(
        "Perhitungan stok menghasilkan nilai yang tidak valid.",
        400
      );
    }

    await updateProductStock(
      connection,
      product.id,
      newStock
    );

    const movementData: StockMovementInsertDto = {
      product_id: input.product_id,
      supplier_id: input.supplier_id ?? null,
      customer_name: input.customer_name?.trim() || null,
      user_id: context.userId,
      type: input.type,
      quantity: input.quantity,
      transaction_date: input.transaction_date ?? null,
      note: input.note?.trim() || null,
    };

    const movementId = await insertStockMovement(
      connection,
      movementData
    );

    await connection.commit();
    transactionStarted = false;

    const result: CreatedStockMovementDto = {
      id: movementId,
      ...movementData,
      stock_before: currentStock,
      stock_after: newStock,
    };

    return result;
  } catch (error) {
    if (connection && transactionStarted) {
      try {
        await connection.rollback();
      } catch (rollbackError) {
        console.error(
          "Gagal melakukan rollback transaksi stok:",
          rollbackError
        );
      }
    }

    throw error;
  } finally {
    connection?.release();
  }
}

export { StockMovementError };
