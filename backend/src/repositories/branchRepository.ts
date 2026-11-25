import type {
  ResultSetHeader,
  RowDataPacket,
} from "mysql2";

import pool from "../db";

export interface BranchRow extends RowDataPacket {
  id: number;
  user_id: number;
  name: string;
  created_at: Date;
}

export const findBranchesByOwner = async (
  ownerId: number
): Promise<BranchRow[]> => {
  const [rows] = await pool.execute<BranchRow[]>(
    `SELECT id, user_id, name, created_at
     FROM branches
     WHERE user_id = ?
     ORDER BY id DESC`,
    [ownerId]
  );

  return rows;
};

export const createBranchRecord = async (
  ownerId: number,
  name: string
): Promise<BranchRow | null> => {
  const [result] = await pool.execute<ResultSetHeader>(
    `INSERT INTO branches (user_id, name)
     VALUES (?, ?)`,
    [ownerId, name]
  );

  const [rows] = await pool.execute<BranchRow[]>(
    `SELECT id, user_id, name, created_at
     FROM branches
     WHERE id = ? AND user_id = ?
     LIMIT 1`,
    [result.insertId, ownerId]
  );

  return rows[0] ?? null;
};

export const deleteBranchRecord = async (
  branchId: number,
  ownerId: number
): Promise<boolean> => {
  const [result] = await pool.execute<ResultSetHeader>(
    `DELETE FROM branches
     WHERE id = ? AND user_id = ?`,
    [branchId, ownerId]
  );

  return result.affectedRows > 0;
};