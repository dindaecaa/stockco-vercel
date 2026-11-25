
export interface CreateDamagedItemDto {
  product_name: string;
  product_sku: string;
  location?: string | null;
  quantity: number;
  reason: string;
  note?: string | null;
  photo_key?: string | null;
}

export interface UpdateDamagedItemStatusDto {
  status: "Disetujui" | "Ditolak";
}

export interface DamagedItemDto {
  id: number;
  owner_id: number;
  product_id: number | null;
  product_name: string;
  product_sku: string | null;
  location: string | null;
  quantity: number;
  reason: string;
  note: string | null;
  status: string;
  photo_key: string | null;
  created_at: Date | string;
}

export interface CreatedDamagedItemDto {
  id: number;
  product_id: number;
  product_name: string;
  product_sku: string | null;
  location: string | null;
  quantity: number;
  reason: string;
  note: string | null;
  status: string;
  photo_key: string | null;
}
