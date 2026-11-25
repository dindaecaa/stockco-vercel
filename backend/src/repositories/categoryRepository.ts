
import type { ResultSetHeader, RowDataPacket } from "mysql2/promise";
import pool from "../db";

export interface CategoryRow extends RowDataPacket {
  id: number;
  name: string;
  description: string | null;
  item_count: number;
}

interface ExistingCategoryRow extends RowDataPacket {
  id: number;
}

interface ProductCountRow extends RowDataPacket {
  total: number;
}

export const categoryRepository = {
  async findAll(ownerId: number): Promise<CategoryRow[]> {
    const [rows] = await pool.execute<CategoryRow[]>(
      `SELECT
         c.id,
         c.name,
         c.description,
         COUNT(p.id) AS item_count
       FROM categories c
       LEFT JOIN products p
         ON p.category_id = c.id
         AND p.owner_id = ?
       GROUP BY c.id, c.name, c.description
       ORDER BY c.name ASC`,
      [ownerId]
    );

    return rows;
  },

  async findById(id: number): Promise<ExistingCategoryRow | null> {
    const [rows] = await pool.execute<ExistingCategoryRow[]>(
      `SELECT id
       FROM categories
       WHERE id = ?
       LIMIT 1`,
      [id]
    );

    return rows[0] ?? null;
  },

  async findDuplicateName(
    name: string,
    excludeId?: number
  ): Promise<ExistingCategoryRow | null> {
    let sql = `
      SELECT id
      FROM categories
      WHERE LOWER(name) = LOWER(?)
    `;

    const params: (string | number)[] = [name];

    if (excludeId !== undefined) {
      sql += " AND id != ?";
      params.push(excludeId);
    }

    sql += " LIMIT 1";

    const [rows] = await pool.execute<ExistingCategoryRow[]>(
      sql,
      params
    );

    return rows[0] ?? null;
  },

  async create(
    name: string,
    description: string | null
  ): Promise<number> {
    const [result] = await pool.execute<ResultSetHeader>(
      `INSERT INTO categories (name, description)
       VALUES (?, ?)`,
      [name, description]
    );

    return result.insertId;
  },

  async update(
    id: number,
    name: string,
    description: string | null
  ): Promise<boolean> {
    const [result] = await pool.execute<ResultSetHeader>(
      `UPDATE categories
       SET name = ?, description = ?
       WHERE id = ?`,
      [name, description, id]
    );

    return result.affectedRows > 0;
  },

  async countProducts(id: number): Promise<number> {
    const [rows] = await pool.execute<ProductCountRow[]>(
      `SELECT COUNT(*) AS total
       FROM products
       WHERE category_id = ?`,
      [id]
    );

    return Number(rows[0]?.total ?? 0);
  },

  async delete(id: number): Promise<boolean> {
    const [result] = await pool.execute<ResultSetHeader>(
      `DELETE FROM categories
       WHERE id = ?`,
      [id]
    );

    return result.affectedRows > 0;
  },
};
