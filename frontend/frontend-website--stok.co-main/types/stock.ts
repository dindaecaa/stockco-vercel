
export interface Stock {
  id: string;
  name: string;
  sku: string;
  category: string;
  stock: number;
  location: string;
  description?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface StockInput {
  name: string;
  sku: string;
  category: string;
  stock: number;
  location: string;
  description?: string;
}
