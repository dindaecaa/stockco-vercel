
export interface CreateCategoryDto {
  name: string;
  description?: string | null;
}

export interface UpdateCategoryDto {
  name: string;
  description?: string | null;
}

export interface CategoryDto {
  id: number;
  name: string;
  description: string | null;
  item_count: number;
}
