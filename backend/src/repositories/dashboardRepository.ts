
import type { RowDataPacket } from "mysql2/promise";
import pool from "../db";

// ==========================================
// DASHBOARD PRODUCT SUMMARY
// ==========================================

export interface DashboardProductRow extends RowDataPacket {
  total_sku: number | string;
  total_stock: number | string;
  out_of_stock: number | string;
  low_stock: number | string;
}

// ==========================================
// DASHBOARD STOCK ALERTS
// ==========================================

export interface DashboardStockAlertRow extends RowDataPacket {
  product_id: number;
  product_name: string;
  sku: string | null;
  stock: number | string;
  minimum_stock: number | string;
  unit: string | null;
  location: string | null;
  alert_type: "out_of_stock" | "low_stock";
}

// ==========================================
// DASHBOARD MOVEMENT SUMMARY
// ==========================================

export interface DashboardMovementRow extends RowDataPacket {
  stock_in_30_days: number | string | null;
  stock_out_30_days: number | string | null;
  stock_in_previous_30_days: number | string | null;
  stock_out_previous_30_days: number | string | null;
}

export interface DashboardMonthlyMovementRow extends RowDataPacket {
  month_key: string;
  stock_in: number | string | null;
  stock_out: number | string | null;
}

// ==========================================
// DASHBOARD CATEGORY SUMMARY
// ==========================================

export interface DashboardCategoryRow extends RowDataPacket {
  category_id: number | null;
  category_name: string;
  total_products: number | string;
}

// ==========================================
// GET PRODUCT SUMMARY
// ==========================================

export async function getProductSummary(
  ownerId: number
): Promise<DashboardProductRow | undefined> {
  const [rows] = await pool.execute<DashboardProductRow[]>(
    `
      SELECT
        COUNT(*) AS total_sku,
        COALESCE(SUM(stock), 0) AS total_stock,

        COALESCE(
          SUM(
            CASE
              WHEN stock <= 0 THEN 1
              ELSE 0
            END
          ),
          0
        ) AS out_of_stock,

        COALESCE(
          SUM(
            CASE
              WHEN stock > 0
                AND stock <= minimum_stock
              THEN 1
              ELSE 0
            END
          ),
          0
        ) AS low_stock

      FROM products
      WHERE owner_id = ?
    `,
    [ownerId]
  );

  return rows[0];
}

// ==========================================
// GET PRODUCT STOCK ALERTS
// ==========================================

export async function getStockAlerts(
  ownerId: number
): Promise<DashboardStockAlertRow[]> {
  const [rows] = await pool.execute<DashboardStockAlertRow[]>(
    `
      SELECT
        id AS product_id,
        name AS product_name,
        sku,
        stock,
        minimum_stock,
        unit,
        location,

        CASE
          WHEN stock <= 0 THEN 'out_of_stock'
          ELSE 'low_stock'
        END AS alert_type

      FROM products

      WHERE owner_id = ?
        AND (
          stock <= 0
          OR (
            stock > 0
            AND stock <= minimum_stock
          )
        )

      ORDER BY
        CASE
          WHEN stock <= 0 THEN 0
          ELSE 1
        END ASC,
        stock ASC,
        name ASC

      LIMIT 10
    `,
    [ownerId]
  );

  return rows;
}

// ==========================================
// GET CATEGORY SUMMARY
// ==========================================

export async function getCategorySummary(
  ownerId: number
): Promise<DashboardCategoryRow[]> {
  const [rows] = await pool.execute<DashboardCategoryRow[]>(
    `
      SELECT
        c.id AS category_id,

        COALESCE(
          c.name,
          'Tanpa Kategori'
        ) AS category_name,

        COUNT(p.id) AS total_products

      FROM products p

      LEFT JOIN categories c
        ON c.id = p.category_id

      WHERE p.owner_id = ?

      GROUP BY
        c.id,
        c.name

      ORDER BY
        total_products DESC,
        category_name ASC
    `,
    [ownerId]
  );

  return rows;
}

// ==========================================
// GET MOVEMENT SUMMARY
// ==========================================

export async function getMovementSummary(
  ownerId: number
): Promise<DashboardMovementRow | undefined> {
  const [rows] = await pool.execute<DashboardMovementRow[]>(
    `
      SELECT
        COALESCE(
          SUM(
            CASE
              WHEN sm.type = 'in'
                AND sm.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
              THEN sm.quantity
              ELSE 0
            END
          ),
          0
        ) AS stock_in_30_days,

        COALESCE(
          SUM(
            CASE
              WHEN sm.type = 'out'
                AND sm.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
              THEN sm.quantity
              ELSE 0
            END
          ),
          0
        ) AS stock_out_30_days,

        COALESCE(
          SUM(
            CASE
              WHEN sm.type = 'in'
                AND sm.created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)
                AND sm.created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
              THEN sm.quantity
              ELSE 0
            END
          ),
          0
        ) AS stock_in_previous_30_days,

        COALESCE(
          SUM(
            CASE
              WHEN sm.type = 'out'
                AND sm.created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY)
                AND sm.created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)
              THEN sm.quantity
              ELSE 0
            END
          ),
          0
        ) AS stock_out_previous_30_days

      FROM stock_movements sm

      INNER JOIN products p
        ON p.id = sm.product_id
        AND p.owner_id = ?
    `,
    [ownerId]
  );

  return rows[0];
}

// ==========================================
// GET MONTHLY MOVEMENT SUMMARY
// ==========================================

export async function getMonthlyMovementSummary(
  ownerId: number,
  startDate: string
): Promise<DashboardMonthlyMovementRow[]> {
  const [rows] = await pool.execute<DashboardMonthlyMovementRow[]>(
    `
      SELECT
        DATE_FORMAT(movement_date, '%Y-%m') AS month_key,

        COALESCE(
          SUM(
            CASE
              WHEN movement_type = 'in'
              THEN quantity
              ELSE 0
            END
          ),
          0
        ) AS stock_in,

        COALESCE(
          SUM(
            CASE
              WHEN movement_type = 'out'
              THEN quantity
              ELSE 0
            END
          ),
          0
        ) AS stock_out

      FROM (
        SELECT
          sm.type AS movement_type,
          sm.quantity,
          COALESCE(
            sm.transaction_date,
            DATE(sm.created_at)
          ) AS movement_date

        FROM stock_movements sm

        INNER JOIN products p
          ON p.id = sm.product_id
          AND p.owner_id = ?
      ) AS movements

      WHERE movement_date >= ?
        AND movement_date < DATE_ADD(CURDATE(), INTERVAL 1 DAY)

      GROUP BY DATE_FORMAT(movement_date, '%Y-%m')
      ORDER BY month_key ASC
    `,
    [ownerId, startDate]
  );

  return rows;
}
