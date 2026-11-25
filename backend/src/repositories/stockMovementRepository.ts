
import type {
  PoolConnection,
  ResultSetHeader,
  RowDataPacket,
} from "mysql2/promise";

import pool from "../db";

import type {
  StockMovementDto,
  StockMovementInsertDto,
} from "../dto/stockMovementDto";

// ==========================================
// INTERFACES
// ==========================================

export interface StockMovementRow
  extends RowDataPacket,
    StockMovementDto {}

export interface ProductStockRow extends RowDataPacket {
  id: number;
  stock: number;
}

export interface SupplierRow extends RowDataPacket {
  id: number;
}

export interface TodayReceivingRow extends RowDataPacket {
  id: number;
  product_name: string;
  product_sku: string | null;
  quantity: number;
  unit: string | null;
  location: string | null;
  supplier_name: string | null;
  transaction_date: string | Date | null;
  created_at: string | Date;
}

// ==========================================
// GET ALL STOCK MOVEMENTS
// ==========================================

export async function findAllStockMovements(
  ownerId: number
): Promise<StockMovementRow[]> {
  const [rows] = await pool.execute<StockMovementRow[]>(
    `
      SELECT
        sm.id,
        sm.product_id,
        sm.supplier_id,
        s.name AS supplier_name,
        sm.customer_name,
        p.name AS product_name,
        p.sku AS product_sku,
        sm.type,
        sm.quantity,
        sm.transaction_date,
        sm.note,
        sm.created_at
      FROM stock_movements sm
      INNER JOIN products p
        ON sm.product_id = p.id
        AND p.owner_id = ?
      LEFT JOIN suppliers s
        ON sm.supplier_id = s.id
        AND s.owner_id = ?
      ORDER BY sm.created_at DESC, sm.id DESC
    `,
    [ownerId, ownerId]
  );

  return rows;
}

// ==========================================
// GET TODAY STOCK RECEIVING
// ==========================================

export async function findTodayStockIns(
  ownerId: number
): Promise<TodayReceivingRow[]> {
  const [rows] = await pool.execute<TodayReceivingRow[]>(
    `
      SELECT
        sm.id,
        p.name AS product_name,
        p.sku AS product_sku,
        sm.quantity,
        p.unit,
        p.location,
        s.name AS supplier_name,
        sm.transaction_date,
        sm.created_at
      FROM stock_movements sm
      INNER JOIN products p
        ON sm.product_id = p.id
        AND p.owner_id = ?
      LEFT JOIN suppliers s
        ON sm.supplier_id = s.id
        AND s.owner_id = ?
      WHERE sm.type = 'in'
        AND COALESCE(
          sm.transaction_date,
          DATE(sm.created_at)
        ) = CURDATE()
      ORDER BY sm.created_at DESC, sm.id DESC
      LIMIT 5
    `,
    [ownerId, ownerId]
  );

  return rows;
}

// ==========================================
// FIND PRODUCT FOR UPDATE
// ==========================================

export async function findProductForUpdate(
  connection: PoolConnection,
  productId: number,
  ownerId: number
): Promise<ProductStockRow | null> {
  const [rows] = await connection.execute<ProductStockRow[]>(
    `
      SELECT id, stock
      FROM products
      WHERE id = ?
        AND owner_id = ?
      LIMIT 1
      FOR UPDATE
    `,
    [productId, ownerId]
  );

  return rows[0] ?? null;
}

// ==========================================
// FIND SUPPLIER BY ID
// ==========================================

export async function findSupplierById(
  connection: PoolConnection,
  supplierId: number,
  ownerId: number
): Promise<SupplierRow | null> {
  const [rows] = await connection.execute<SupplierRow[]>(
    `
      SELECT id
      FROM suppliers
      WHERE id = ?
        AND owner_id = ?
      LIMIT 1
      FOR UPDATE
    `,
    [supplierId, ownerId]
  );

  return rows[0] ?? null;
}

// ==========================================
// UPDATE PRODUCT STOCK
// ==========================================

export async function updateProductStock(
  connection: PoolConnection,
  productId: number,
  newStock: number
): Promise<void> {
  await connection.execute(
    `
      UPDATE products
      SET stock = ?,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `,
    [newStock, productId]
  );
}

// ==========================================
// INSERT STOCK MOVEMENT
// ==========================================

export async function insertStockMovement(
  connection: PoolConnection,
  data: StockMovementInsertDto
): Promise<number> {
  const [result] = await connection.execute<ResultSetHeader>(
    `
      INSERT INTO stock_movements (
        product_id,
        supplier_id,
        customer_name,
        user_id,
        type,
        quantity,
        transaction_date,
        note
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `,
    [
      data.product_id,
      data.supplier_id,
      data.customer_name,
      data.user_id,
      data.type,
      data.quantity,
      data.transaction_date,
      data.note,
    ]
  );

  return result.insertId;
}
