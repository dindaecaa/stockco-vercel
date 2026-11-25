
import type {
  ResultSetHeader,
  RowDataPacket,
} from "mysql2/promise";

import pool from "../db";

export interface DamagedItemRow extends RowDataPacket {
  id: number;
  owner_id: number;
  product_id: number | null;
  product_name: string;
  product_sku: string | null;
  location: string | null;
  quantity: number;
  reason: string;
  note: string | null;
  status: string;
  photo_key: string | null;
  created_at: Date;
}

export interface ProductLookupRow extends RowDataPacket {
  id: number;
  name: string;
  sku: string | null;
  location: string | null;
}

export const damagedItemRepository = {
  async findAll(ownerId: number): Promise<DamagedItemRow[]> {
    const [rows] = await pool.execute<DamagedItemRow[]>(
      `SELECT
         id,
         owner_id,
         product_id,
         product_name,
         product_sku,
         location,
         quantity,
         reason,
         note,
         status,
         photo_key,
         created_at
       FROM damaged_items
       WHERE owner_id = ?
       ORDER BY created_at DESC`,
      [ownerId]
    );

    return rows;
  },

  async findProductBySku(
    sku: string,
    ownerId: number
  ): Promise<ProductLookupRow | null> {
    const [rows] = await pool.execute<ProductLookupRow[]>(
      `SELECT
         id,
         name,
         sku,
         location
       FROM products
       WHERE sku = ?
         AND owner_id = ?
       LIMIT 1`,
      [sku, ownerId]
    );

    return rows[0] ?? null;
  },

  async create(
    ownerId: number,
    data: {
      productId: number;
      productName: string;
      productSku: string | null;
      location: string | null;
      quantity: number;
      reason: string;
      note: string | null;
      photoKey: string | null;
    }
  ): Promise<number> {
    const [result] = await pool.execute<ResultSetHeader>(
      `INSERT INTO damaged_items (
         owner_id,
         product_id,
         product_name,
         product_sku,
         location,
         quantity,
         reason,
         note,
         status,
         photo_key
       )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        ownerId,
        data.productId,
        data.productName,
        data.productSku,
        data.location,
        data.quantity,
        data.reason,
        data.note,
        "Belum ditindaklanjuti",
        data.photoKey,
      ]
    );

    return result.insertId;
  },

  async updatePendingStatus(
    id: number,
    ownerId: number,
    status: "Disetujui" | "Ditolak"
  ): Promise<boolean> {
    const [result] = await pool.execute<ResultSetHeader>(
      `UPDATE damaged_items
       SET status = ?
       WHERE id = ?
         AND owner_id = ?
         AND status = 'Belum ditindaklanjuti'`,
      [status, id, ownerId]
    );

    return result.affectedRows > 0;
  },
};
