
import { apiFetch } from "@/lib/api";
import type {
  Supplier,
  SupplierInput,
} from "@/types/supplier";

interface APISupplier {
  id: number;
  name: string;
  phone: string | null;
  email: string | null;
  address: string | null;
  created_at?: string;
}

interface APIResponse<T> {
  success: boolean;
  message?: string;
  data?: T;
  supplierId?: number;
}

function mapSupplier(item: APISupplier): Supplier {
  return {
    id: String(item.id),
    name: item.name,
    phone: item.phone || "",
    email: item.email || "",
    address: item.address || "",
    createdAt: item.created_at,
  };
}

export async function getSuppliers(): Promise<Supplier[]> {
  const response = await apiFetch("suppliers", {
    method: "GET",
    cache: "no-store",
  });

  const result: APIResponse<APISupplier[]> =
    await response.json();

  if (!response.ok || !result.success) {
    throw new Error(
      result.message || "Gagal mengambil data pemasok."
    );
  }

  return (result.data ?? []).map(mapSupplier);
}

export async function createSupplier(
  data: SupplierInput
): Promise<{ supplierId: number; message: string }> {
  const response = await apiFetch("suppliers", {
    method: "POST",
    body: JSON.stringify(data),
  });

  const result: APIResponse<never> =
    await response.json();

  if (!response.ok || !result.success) {
    throw new Error(
      result.message || "Gagal menambahkan pemasok."
    );
  }

  return {
    supplierId: result.supplierId ?? 0,
    message: result.message || "Pemasok berhasil ditambahkan.",
  };
}

export async function updateSupplier(
  id: string,
  data: SupplierInput
): Promise<void> {
  const response = await apiFetch(`suppliers/${id}`, {
    method: "PUT",
    body: JSON.stringify(data),
  });

  const result: APIResponse<never> =
    await response.json();

  if (!response.ok || !result.success) {
    throw new Error(
      result.message || "Gagal memperbarui pemasok."
    );
  }
}

export async function deleteSupplier(
  id: string
): Promise<void> {
  const response = await apiFetch(`suppliers/${id}`, {
    method: "DELETE",
  });

  const result: APIResponse<never> =
    await response.json();

  if (!response.ok || !result.success) {
    throw new Error(
      result.message || "Gagal menghapus pemasok."
    );
  }
}
