"use client";

import { useEffect, useState } from "react";

import { apiFetch } from "@/lib/api";

interface StockMovement {
  id: number;
  product_id: number;
  supplier_id: number | null;
  supplier_name?: string | null;
  customer_name: string | null;
  product_name: string;
  product_sku: string | null;
  type: "in" | "out";
  quantity: number;
  transaction_date: string | null;
  note: string | null;
  created_at: string;
}

interface StockMovementResponse {
  success: boolean;
  message?: string;
  data: StockMovement[];
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat("id-ID").format(value);
}

function getJakartaDateKey(value: string | Date): string {
  const date = value instanceof Date ? value : new Date(value);

  if (Number.isNaN(date.getTime())) return "";

  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Jakarta",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);

  const year = parts.find((p) => p.type === "year")?.value;
  const month = parts.find((p) => p.type === "month")?.value;
  const day = parts.find((p) => p.type === "day")?.value;

  return `${year}-${month}-${day}`;
}

function getTodayJakarta(): string {
  return getJakartaDateKey(new Date());
}

function getMovementDate(item: StockMovement): string {
  if (item.transaction_date) {
    const value = String(item.transaction_date);

    // Jika tanggal berbentuk YYYY-MM-DD, gunakan tanggal tersebut langsung.
    if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return value;
    }

    const parsed = new Date(value);

    if (!Number.isNaN(parsed.getTime())) {
      return getJakartaDateKey(parsed);
    }
  }

  return getJakartaDateKey(item.created_at);
}

function formatDateTime(value: string | null): string {
  if (!value) return "—";

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) return "—";

  return new Intl.DateTimeFormat("id-ID", {
    timeZone: "Asia/Jakarta",
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

export default function StockOutCard() {
  const [data, setData] = useState<StockMovement[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let isMounted = true;

    async function fetchTodayStockOut() {
      try {
        const response = await apiFetch("stock-movements", {
          method: "GET",
          cache: "no-store",
        });

        const result: StockMovementResponse = await response.json();

        if (
          !response.ok ||
          !result.success ||
          !Array.isArray(result.data)
        ) {
          throw new Error(
            result.message || "Gagal mengambil data stok keluar."
          );
        }

        const today = getTodayJakarta();

        const todayStockOut = result.data
          .filter(
            (item) =>
              item.type === "out" &&
              getMovementDate(item) === today
          )
          .sort((a, b) => {
            const dateA = new Date(a.created_at).getTime();
            const dateB = new Date(b.created_at).getTime();

            return dateB - dateA;
          });

        if (isMounted) {
          setData(todayStockOut);
          setError("");
        }
      } catch (err) {
        if (isMounted) {
          setError(
            err instanceof Error
              ? err.message
              : "Terjadi kesalahan saat mengambil data stok keluar."
          );
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchTodayStockOut();

    const interval = window.setInterval(fetchTodayStockOut, 15000);

    const handleFocus = () => {
      fetchTodayStockOut();
    };

    window.addEventListener("focus", handleFocus);

    return () => {
      isMounted = false;
      window.clearInterval(interval);
      window.removeEventListener("focus", handleFocus);
    };
  }, []);

  return (
    <section className="receiving-dashboard-card">
      <div className="receiving-dashboard-header">
        <div className="receiving-title">
          <h2>Stok Keluar Hari Ini</h2>
        </div>
      </div>

      <div className="receiving-table-wrapper">
        <table className="receiving-dashboard-table">
          <thead>
            <tr>
              <th>No</th>
              <th>Nama Barang</th>
              <th>SKU</th>
              <th>Jumlah Keluar</th>
              <th>Waktu Keluar</th>
              <th>Tujuan</th>
              <th>Catatan</th>
              <th>Status</th>
            </tr>
          </thead>

          <tbody>
            {loading && (
              <tr>
                <td colSpan={8}>Memuat data stok keluar...</td>
              </tr>
            )}

            {!loading && error && (
              <tr>
                <td colSpan={8} role="alert">
                  {error}
                </td>
              </tr>
            )}

            {!loading && !error && data.length === 0 && (
              <tr>
                <td colSpan={8}>
                  Belum ada stok keluar hari ini.
                </td>
              </tr>
            )}

            {!loading &&
              !error &&
              data.map((item, index) => (
                <tr key={item.id}>
                  <td>{index + 1}</td>

                  <td>
                    <span className="receiving-product">
                      {item.product_name}
                    </span>
                  </td>

                  <td>{item.product_sku || "—"}</td>

                  <td>{formatNumber(Number(item.quantity) || 0)}</td>

                  <td>{formatDateTime(item.created_at)}</td>

                  <td>{item.customer_name || "—"}</td>

                  <td>{item.note || "—"}</td>

                  <td>
                    <span className="status-received">
                      Dikeluarkan
                    </span>
                  </td>
                </tr>
              ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}