
import type {
  ResultSetHeader,
  RowDataPacket,
} from "mysql2/promise";

import pool from "../db";

export interface SupplierRow extends RowDataPacket {
  id: number;
  name: string;
  phone: string | null;
  email: string | null;
  address: string | null;
  owner_id: number;
  created_at: Date;
}

export const supplierRepository = {
  async findAll(ownerId: number): Promise<SupplierRow[]> {
    const [rows] = await pool.execute<SupplierRow[]>(
      `SELECT
         id,
         name,
         phone,
         email,
         address,
         owner_id,
         created_at
       FROM suppliers
       WHERE owner_id = ?
       ORDER BY created_at DESC`,
      [ownerId]
    );

    return rows;
  },

  async findById(
    id: number,
    ownerId: number
  ): Promise<SupplierRow | null> {
    const [rows] = await pool.execute<SupplierRow[]>(
      `SELECT
         id,
         name,
         phone,
         email,
         address,
         owner_id,
         created_at
       FROM suppliers
       WHERE id = ? AND owner_id = ?
       LIMIT 1`,
      [id, ownerId]
    );

    return rows[0] ?? null;
  },

  async create(
    ownerId: number,
    data: {
      name: string;
      phone: string | null;
      email: string | null;
      address: string | null;
    }
  ): Promise<number> {
    const [result] = await pool.execute<ResultSetHeader>(
      `INSERT INTO suppliers (
         owner_id,
         name,
         phone,
         email,
         address
       )
       VALUES (?, ?, ?, ?, ?)`,
      [
        ownerId,
        data.name,
        data.phone,
        data.email,
        data.address,
      ]
    );

    return result.insertId;
  },

  async update(
    id: number,
    ownerId: number,
    data: {
      name: string;
      phone: string | null;
      email: string | null;
      address: string | null;
    }
  ): Promise<boolean> {
    const [result] = await pool.execute<ResultSetHeader>(
      `UPDATE suppliers
       SET
         name = ?,
         phone = ?,
         email = ?,
         address = ?
       WHERE id = ? AND owner_id = ?`,
      [
        data.name,
        data.phone,
        data.email,
        data.address,
        id,
        ownerId,
      ]
    );

    return result.affectedRows > 0;
  },

  async delete(
    id: number,
    ownerId: number
  ): Promise<boolean> {
    const [result] = await pool.execute<ResultSetHeader>(
      `DELETE FROM suppliers
       WHERE id = ? AND owner_id = ?`,
      [id, ownerId]
    );

    return result.affectedRows > 0;
  },
};
