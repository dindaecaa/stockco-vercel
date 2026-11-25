
import type { RowDataPacket } from "mysql2/promise";
import pool from "../db";

export interface StockAlertRow extends RowDataPacket {
  id: number;
  name: string;
  sku: string | null;
  stock: number;
  minimum_stock: number;
  unit: string | null;
  location: string | null;
}

export async function findStockAlerts(
  ownerId: number
): Promise<StockAlertRow[]> {
  const [rows] = await pool.execute<StockAlertRow[]>(
    `
      SELECT
        id,
        name,
        sku,
        stock,
        minimum_stock,
        unit,
        location
      FROM products
      WHERE owner_id = ?
        AND stock <= minimum_stock
      ORDER BY stock ASC, name ASC
    `,
    [ownerId]
  );

  return rows;
}

