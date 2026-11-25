
export type StockAlertStatus = "habis" | "menipis";

export interface StockNotificationDto {
  id: number;
  name: string;
  sku: string | null;
  stock: number;
  minimum_stock: number;
  unit: string | null;
  location: string | null;
  status: StockAlertStatus;
  message: string;
}

export interface AIStockDto {
  total_alerts: number;
  out_of_stock_count: number;
  low_stock_count: number;
  notifications: StockNotificationDto[];
  recommendation: string;
}
