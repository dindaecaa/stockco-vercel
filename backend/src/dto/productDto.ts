export interface CreateProductDto {
  name: string;
  supplier_id?: number | null;
  reseller_name?: string | null;
  sku?: string | null;
  description?: string | null;
  stock: number;
  minimum_stock?: number;
  unit?: string | null;
  price?: number;
  location?: string | null;
  category_id?: number | null;
  category?: string | null;
}

export interface UpdateProductDto {
  name: string;
  supplier_id?: number | null;
  reseller_name?: string | null;
  sku?: string | null;
  description?: string | null;
  stock: number;
  minimum_stock?: number;
  unit?: string | null;
  price: number;
  location?: string | null;
  category_id?: number | null | "";
  category?: string | null;
}

export interface ProductDto {
  id: number;
  owner_id: number;
  category_id: number | null;
  category_name?: string | null;
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
  image_key?: string | null;
  created_at?: Date | string;
  updated_at?: Date | string;
}