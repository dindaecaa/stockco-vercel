
import type {
  PoolConnection,
  ResultSetHeader,
  RowDataPacket,
} from "mysql2/promise";

import pool from "../db";

// ==========================================
// INTERFACES
// ==========================================

export interface ProductRow extends RowDataPacket {
  id: number;
  owner_id: number;
  category_id: number | null;
  category_name: string | null;
  supplier_id: number | null;
  supplier_name: string | null;
  name: string;
  reseller_name: string | null;
  sku: string | null;
  description: string | null;
  stock: number;
  minimum_stock: number;
  unit: string | null;
  price: number;
  location: string | null;
  image_key: string | null;
}

interface CategoryRow extends RowDataPacket {
  id: number;
  name: string;
}

interface ProductWriteData {
  categoryId: number | null;
  supplierId: number | null;
  name: string;
  resellerName: string | null;
  sku: string | null;
  description: string | null;
  stock: number;
  minimumStock: number;
  unit: string | null;
  price: number;
  location: string | null;
}

// ==========================================
// PRODUCT REPOSITORY
// ==========================================

export const productRepository = {
  // ----------------------------------------
  // GET ALL PRODUCTS
  // ----------------------------------------

  async findAll(ownerId: number): Promise<ProductRow[]> {
    const [rows] = await pool.execute<ProductRow[]>(
      `SELECT
         p.*,
         c.name AS category_name,
         s.name AS supplier_name
       FROM products p
       LEFT JOIN categories c
         ON c.id = p.category_id
       LEFT JOIN suppliers s
         ON s.id = p.supplier_id
         AND s.owner_id = p.owner_id
       WHERE p.owner_id = ?
       ORDER BY p.created_at DESC`,
      [ownerId]
    );

    return rows;
  },

  // ----------------------------------------
  // GET PRODUCT BY ID
  // ----------------------------------------

  async findById(
    id: number,
    ownerId: number,
    connection?: PoolConnection
  ): Promise<ProductRow | null> {
    const executor = connection ?? pool;

    const [rows] = await executor.execute<ProductRow[]>(
      `SELECT
         p.*,
         c.name AS category_name,
         s.name AS supplier_name
       FROM products p
       LEFT JOIN categories c
         ON c.id = p.category_id
       LEFT JOIN suppliers s
         ON s.id = p.supplier_id
         AND s.owner_id = p.owner_id
       WHERE p.id = ?
         AND p.owner_id = ?
       LIMIT 1`,
      [id, ownerId]
    );

    return rows[0] ?? null;
  },

  // ----------------------------------------
  // GET PRODUCT FOR UPDATE
  // Mengunci baris produk selama transaksi.
  // ----------------------------------------

  async findByIdForUpdate(
    id: number,
    ownerId: number,
    connection: PoolConnection
  ): Promise<ProductRow | null> {
    const [rows] = await connection.execute<ProductRow[]>(
      `SELECT
         p.*,
         c.name AS category_name,
         s.name AS supplier_name
       FROM products p
       LEFT JOIN categories c
         ON c.id = p.category_id
       LEFT JOIN suppliers s
         ON s.id = p.supplier_id
         AND s.owner_id = p.owner_id
       WHERE p.id = ?
         AND p.owner_id = ?
       LIMIT 1
       FOR UPDATE`,
      [id, ownerId]
    );

    return rows[0] ?? null;
  },

  // ----------------------------------------
  // FIND CATEGORY BY ID
  // ----------------------------------------

  async findCategoryById(
    categoryId: number,
    connection?: PoolConnection
  ): Promise<CategoryRow | null> {
    const executor = connection ?? pool;

    const [rows] = await executor.execute<CategoryRow[]>(
      `SELECT id, name
       FROM categories
       WHERE id = ?
       LIMIT 1`,
      [categoryId]
    );

    return rows[0] ?? null;
  },

  // ----------------------------------------
  // FIND CATEGORY BY NAME
  // ----------------------------------------

  async findCategoryByName(
    name: string,
    connection?: PoolConnection
  ): Promise<CategoryRow | null> {
    const executor = connection ?? pool;

    const [rows] = await executor.execute<CategoryRow[]>(
      `SELECT id, name
       FROM categories
       WHERE LOWER(name) = LOWER(?)
       LIMIT 1`,
      [name]
    );

    return rows[0] ?? null;
  },

  // ----------------------------------------
  // CREATE PRODUCT
  // ----------------------------------------

  async create(
    ownerId: number,
    data: ProductWriteData,
    connection: PoolConnection
  ): Promise<number> {
    const [result] = await connection.execute<ResultSetHeader>(
      `INSERT INTO products (
         owner_id,
         category_id,
         supplier_id,
         name,
         reseller_name,
         sku,
         description,
         stock,
         minimum_stock,
         unit,
         price,
         location
       )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        ownerId,
        data.categoryId,
        data.supplierId,
        data.name,
        data.resellerName,
        data.sku,
        data.description,
        data.stock,
        data.minimumStock,
        data.unit,
        data.price,
        data.location,
      ]
    );

    return result.insertId;
  },

  // ----------------------------------------
  // UPDATE PRODUCT
  // Bisa menggunakan koneksi transaksi.
  // ----------------------------------------

  async update(
    id: number,
    ownerId: number,
    data: ProductWriteData,
    connection?: PoolConnection
  ): Promise<boolean> {
    const executor = connection ?? pool;

    const [result] = await executor.execute<ResultSetHeader>(
      `UPDATE products
       SET name = ?,
           reseller_name = ?,
           category_id = ?,
           supplier_id = ?,
           sku = ?,
           description = ?,
           stock = ?,
           minimum_stock = ?,
           unit = ?,
           price = ?,
           location = ?,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = ?
         AND owner_id = ?`,
      [
        data.name,
        data.resellerName,
        data.categoryId,
        data.supplierId,
        data.sku,
        data.description,
        data.stock,
        data.minimumStock,
        data.unit,
        data.price,
        data.location,
        id,
        ownerId,
      ]
    );

    return result.affectedRows > 0;
  },

  // ----------------------------------------
  // DELETE PRODUCT
  // ----------------------------------------

  async delete(
    id: number,
    ownerId: number
  ): Promise<boolean> {
    const [result] = await pool.execute<ResultSetHeader>(
      `DELETE FROM products
       WHERE id = ?
         AND owner_id = ?`,
      [id, ownerId]
    );

    return result.affectedRows > 0;
  },

  // ----------------------------------------
  // DATABASE TRANSACTION
  // ----------------------------------------

  async withTransaction<T>(
    callback: (connection: PoolConnection) => Promise<T>
  ): Promise<T> {
    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const result = await callback(connection);

      await connection.commit();

      return result;
    } catch (error) {
      try {
        await connection.rollback();
      } catch (rollbackError) {
        console.error(
          "Gagal melakukan rollback transaksi produk:",
          rollbackError
        );
      }

      throw error;
    } finally {
      connection.release();
    }
  },
};
