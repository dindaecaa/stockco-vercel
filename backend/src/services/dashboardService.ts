
import {
  getMovementSummary,
  getProductSummary,
  getMonthlyMovementSummary,
  getCategorySummary,
  getStockAlerts,
} from "../repositories/dashboardRepository";

import type { DashboardDto } from "../dto/dashboardDto";

// ==========================================
// ERROR
// ==========================================

export class DashboardError extends Error {
  statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.name = "DashboardError";
    this.statusCode = statusCode;
  }
}

// ==========================================
// MONTHLY CHART DTO
// ==========================================

export interface DashboardMonthlyChartItem {
  month_key: string;
  month: string;
  stock_in: number;
  stock_out: number;
}

export interface DashboardMonthlyChartDto {
  period: 3 | 6 | 12;
  data: DashboardMonthlyChartItem[];
}

// ==========================================
// CATEGORY CHART DTO
// ==========================================

export interface DashboardCategoryChartItem {
  category_id: number | null;
  category_name: string;
  total_products: number;
  percentage: number;
}

export interface DashboardCategoryChartDto {
  total_products: number;
  data: DashboardCategoryChartItem[];
}

// ==========================================
// STOCK ALERT DTO
// ==========================================

export interface DashboardStockAlertItem {
  product_id: number;
  product_name: string;
  sku: string | null;
  stock: number;
  minimum_stock: number;
  unit: string | null;
  location: string | null;
  alert_type: "out_of_stock" | "low_stock";
}

export interface DashboardStockAlertsDto {
  total: number;
  data: DashboardStockAlertItem[];
}

// ==========================================
// VALIDATION
// ==========================================

function validateOwnerId(ownerId: number | undefined): number {
  if (
    typeof ownerId !== "number" ||
    !Number.isSafeInteger(ownerId) ||
    ownerId <= 0
  ) {
    throw new DashboardError(
      "Akses inventaris tidak diizinkan.",
      403
    );
  }

  return ownerId;
}

function toNumber(
  value: number | string | null | undefined
): number {
  const result = Number(value ?? 0);

  if (!Number.isFinite(result)) {
    return 0;
  }

  return result;
}

function validatePeriod(period: number): 3 | 6 | 12 {
  if (period !== 3 && period !== 6 && period !== 12) {
    throw new DashboardError(
      "Periode grafik harus 3, 6, atau 12 bulan.",
      400
    );
  }

  return period;
}

// ==========================================
// MONTH HELPERS
// ==========================================

function formatMonthKey(year: number, month: number): string {
  return `${year}-${String(month).padStart(2, "0")}`;
}

// ==========================================
// GET DASHBOARD SUMMARY
// ==========================================

export async function getDashboardData(
  ownerId: number | undefined
): Promise<DashboardDto> {
  const validOwnerId = validateOwnerId(ownerId);

  const [product, movement] = await Promise.all([
    getProductSummary(validOwnerId),
    getMovementSummary(validOwnerId),
  ]);

  const dashboardData: DashboardDto = {
    total_sku: toNumber(product?.total_sku),
    total_stock: toNumber(product?.total_stock),
    out_of_stock: toNumber(product?.out_of_stock),
    low_stock: toNumber(product?.low_stock),

    stock_in_30_days: toNumber(
      movement?.stock_in_30_days
    ),

    stock_out_30_days: toNumber(
      movement?.stock_out_30_days
    ),

    stock_in_previous_30_days: toNumber(
      movement?.stock_in_previous_30_days
    ),

    stock_out_previous_30_days: toNumber(
      movement?.stock_out_previous_30_days
    ),
  };

  return dashboardData;
}

// ==========================================
// GET DASHBOARD STOCK ALERTS
// ==========================================

export async function getDashboardStockAlerts(
  ownerId: number | undefined
): Promise<DashboardStockAlertsDto> {
  const validOwnerId = validateOwnerId(ownerId);

  const rows = await getStockAlerts(validOwnerId);

  const data: DashboardStockAlertItem[] = rows.map((row) => ({
    product_id: toNumber(row.product_id),
    product_name: row.product_name,
    sku: row.sku,
    stock: toNumber(row.stock),
    minimum_stock: toNumber(row.minimum_stock),
    unit: row.unit,
    location: row.location,
    alert_type: row.alert_type,
  }));

  return {
    total: data.length,
    data,
  };
}

// ==========================================
// GET DASHBOARD MONTHLY CHART
// ==========================================

export async function getDashboardMonthlyChart(
  ownerId: number | undefined,
  requestedPeriod: number
): Promise<DashboardMonthlyChartDto> {
  const validOwnerId = validateOwnerId(ownerId);
  const period = validatePeriod(requestedPeriod);

  const now = new Date();

  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth() + 1;

  const startDate = new Date(
    currentYear,
    currentMonth - period,
    1
  );

  const startDateString = [
    startDate.getFullYear(),
    String(startDate.getMonth() + 1).padStart(2, "0"),
    "01",
  ].join("-");

  const monthlyRows = await getMonthlyMovementSummary(
    validOwnerId,
    startDateString
  );

  const movementByMonth = new Map(
    monthlyRows.map((row) => [
      row.month_key,
      {
        stock_in: toNumber(row.stock_in),
        stock_out: toNumber(row.stock_out),
      },
    ])
  );

  const data: DashboardMonthlyChartItem[] = [];

  for (let offset = period - 1; offset >= 0; offset--) {
    const date = new Date(
      currentYear,
      currentMonth - 1 - offset,
      1
    );

    const year = date.getFullYear();
    const monthNumber = date.getMonth() + 1;
    const monthKey = formatMonthKey(year, monthNumber);

    const movement = movementByMonth.get(monthKey);

    const monthLabel = new Intl.DateTimeFormat("id-ID", {
      month: "short",
      year: period === 12 ? "2-digit" : undefined,
    }).format(date);

    data.push({
      month_key: monthKey,
      month: monthLabel,
      stock_in: movement?.stock_in ?? 0,
      stock_out: movement?.stock_out ?? 0,
    });
  }

  return {
    period,
    data,
  };
}

// ==========================================
// GET DASHBOARD CATEGORY CHART
// ==========================================

export async function getDashboardCategoryChart(
  ownerId: number | undefined
): Promise<DashboardCategoryChartDto> {
  const validOwnerId = validateOwnerId(ownerId);

  const categoryRows = await getCategorySummary(validOwnerId);

  const dataWithoutPercentage = categoryRows.map((row) => ({
    category_id:
      row.category_id === null
        ? null
        : toNumber(row.category_id),

    category_name: row.category_name,

    total_products: toNumber(row.total_products),
  }));

  const totalProducts = dataWithoutPercentage.reduce(
    (total, category) => total + category.total_products,
    0
  );

  const data: DashboardCategoryChartItem[] =
    dataWithoutPercentage.map((category) => ({
      ...category,
      percentage:
        totalProducts > 0
          ? Number(
              (
                (category.total_products / totalProducts) *
                100
              ).toFixed(2)
            )
          : 0,
    }));

  return {
    total_products: totalProducts,
    data,
  };
}
