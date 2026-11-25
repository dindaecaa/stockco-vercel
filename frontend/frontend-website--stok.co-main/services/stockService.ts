
import { apiFetch } from "@/lib/api";
import type { Stock, StockInput } from "@/types/stock";

interface APIProduct {
  id: number;
  name: string;
  sku: string | null;
  category_name?: string | null;
  stock: number;
  location: string | null;
  description?: string | null;
}

interface APIResponse<T> {
  success: boolean;
  message?: string;
  data: T;
}

function mapProduct(product: APIProduct): Stock {
  return {
    id: String(product.id),
    name: product.name,
    sku: product.sku || `SKU-${product.id}`,
    category: product.category_name || "Lainnya",
    stock: Number(product.stock),
    location: product.location || "-",
    description: product.description || "",
  };
}

export async function getStocks(): Promise<Stock[]> {
  const response = await apiFetch("products", {
    method: "GET",
    cache: "no-store",
  });

  const result: APIResponse<APIProduct[]> =
    await response.json();

  if (!response.ok || !result.success) {
    throw new Error(
      result.message || "Gagal mengambil data stok."
    );
  }

  return result.data.map(mapProduct);
}

export async function createStock(
  data: StockInput
): Promise<Stock> {
  const response = await apiFetch("products", {
    method: "POST",
    body: JSON.stringify({
      name: data.name,
      sku: data.sku,
      category: data.category,
      stock: data.stock,
      location: data.location,
      description: data.description,
      unit: "pcs",
      price: 0,
    }),
  });

  const result: APIResponse<APIProduct> =
    await response.json();

  if (!response.ok || !result.success) {
    throw new Error(
      result.message || "Gagal menambahkan barang."
    );
  }

  return mapProduct(result.data);
}
