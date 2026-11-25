
export interface User {
  id: string;
  name: string;
  email: string;
  role: "admin" | "staff";
  avatar?: string;
}

export interface LoginInput {
  email: string;
  password: string;
}
