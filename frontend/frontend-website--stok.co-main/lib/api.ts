
const API_BASE_URL = (
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3001/api"
).replace(/\/+$/, "");

export function apiUrl(endpoint: string): string {
  const cleanEndpoint = endpoint.replace(/^\/+/, "");
  return `${API_BASE_URL}/${cleanEndpoint}`;
}

export async function apiFetch(
  endpoint: string,
  options: RequestInit = {}
): Promise<Response> {
  const headers = new Headers(options.headers);

  if (typeof window !== "undefined") {
    const token = localStorage.getItem("stockco_token");

    if (token) {
      headers.set("Authorization", `Bearer ${token}`);
    }
  }

  if (
    options.body &&
    typeof options.body === "string" &&
    !headers.has("Content-Type")
  ) {
    headers.set("Content-Type", "application/json");
  }

  return fetch(apiUrl(endpoint), {
    ...options,
    headers,
  });
}

export { API_BASE_URL };
