
export interface Supplier {
  id: string;
  name: string;
  email?: string;
  phone: string;
  address: string;
  createdAt?: string;
}

export interface SupplierInput {
  name: string;
  email?: string;
  phone: string;
  address: string;
}
