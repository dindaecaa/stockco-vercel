
export interface CreateSupplierDto {
  name: string;
  phone?: string | null;
  email?: string | null;
  address?: string | null;
}

export interface UpdateSupplierDto {
  name: string;
  phone?: string | null;
  email?: string | null;
  address?: string | null;
}

export interface SupplierDto {
  id: number;
  name: string;
  phone: string | null;
  email: string | null;
  address: string | null;
  owner_id: number;
  created_at: Date | string;
}
