
export type StockMovementType = "in" | "out";

export interface CreateStockMovementDto {
  product_id: number;
  supplier_id?: number | null;
  customer_name?: string | null;
  type: StockMovementType;
  quantity: number;
  transaction_date?: string | null;
  note?: string | null;
}

export interface StockMovementInsertDto {
  product_id: number;
  supplier_id: number | null;
  customer_name: string | null;
  user_id: number;
  type: StockMovementType;
  quantity: number;
  transaction_date: string | null;
  note: string | null;
}

export interface StockMovementDto {
  id: number;
  product_id: number;
  supplier_id: number | null;
  supplier_name: string | null;
  customer_name: string | null;
  product_name: string;
  product_sku: string | null;
  type: StockMovementType;
  quantity: number;
  transaction_date: string | null;
  note: string | null;
  created_at: Date | string;
}

export interface CreatedStockMovementDto
  extends StockMovementInsertDto {
  id: number;
  stock_before: number;
  stock_after: number;
}
