
import { apiFetch } from "@/lib/api";
import type { LoginInput } from "@/types/user";

export async function loginUser(data: LoginInput) {
  const response = await apiFetch("auth/login", {
    method: "POST",
    body: JSON.stringify(data),
  });

  const result = await response.json();

  if (!response.ok || !result.success) {
    throw new Error(
      result.message || "Email atau password tidak valid."
    );
  }

  return result;
}
