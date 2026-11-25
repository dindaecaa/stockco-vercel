
"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

import { apiFetch } from "@/lib/api";

interface MovementItem {
  id: number;
  product_id: number;
  product_name: string;
  product_sku: string | null;
  supplier_name?: string | null;
  customer_name: string | null;
  type: "in" | "out";
  quantity: number;
  transaction_date: string | null;
  note: string | null;
  created_at: string;
  unit?: string | null;
}

interface MovementResponse {
  success: boolean;
  message?: string;
  data: MovementItem[];
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

function getToday(): string {
  return getJakartaDateKey(new Date());
}

function getMovementDate(item: MovementItem): string {
  if (item.transaction_date) {
    const value = String(item.transaction_date);

    if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      return value;
    }

    const date = new Date(value);

    if (!Number.isNaN(date.getTime())) {
      return getJakartaDateKey(date);
    }
  }

  return getJakartaDateKey(item.created_at);
}

// AMBIL NAMA PEMASOK DARI NOTE TRANSAKSI LAMA
function getSupplierFromNote(note: string | null): string {
  if (!note) return "";

  const match = note.match(
    /Pemasok\s*:\s*(.*?)(?=\s*\|\s*(?:Tanggal penerimaan\s*:|$)|$)/i
  );

  return match?.[1]?.trim() ?? "";
}

// PRIORITAS NAMA SUPPLIER DARI DATABASE,
// JIKA KOSONG AMBIL DARI NOTE
function getSupplierName(item: MovementItem): string {
  if (item.supplier_name?.trim()) {
    return item.supplier_name.trim();
  }

  return getSupplierFromNote(item.note) || "—";
}

function getDestinationName(item: MovementItem): string {
  if (item.type === "in") {
    return getSupplierName(item);
  }

  return item.customer_name?.trim() || "—";
}

function formatDateTime(value: string | null): string {
  if (!value) return "—";

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "—";
  }

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

export default function ReceivingCard() {
  const [data, setData] = useState<MovementItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let isMounted = true;

    async function fetchTodayMovements() {
      try {
        const response = await apiFetch("stock-movements", {
          method: "GET",
          cache: "no-store",
        });

        const result: MovementResponse = await response.json();

        if (
          !response.ok ||
          !result.success ||
          !Array.isArray(result.data)
        ) {
          throw new Error(
            result.message || "Gagal mengambil data pergerakan stok."
          );
        }

        const today = getToday();

        const todayMovements = result.data
          .filter(
            (item) =>
              (item.type === "in" || item.type === "out") &&
              getMovementDate(item) === today
          )
          .sort((a, b) => {
            return (
              new Date(b.created_at).getTime() -
              new Date(a.created_at).getTime()
            );
          });

        if (isMounted) {
          setData(todayMovements);
          setError("");
        }
      } catch (err) {
        if (isMounted) {
          setError(
            err instanceof Error
              ? err.message
              : "Terjadi kesalahan saat mengambil pergerakan stok."
          );
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchTodayMovements();

    const interval = window.setInterval(fetchTodayMovements, 15000);

    const handleFocus = () => {
      fetchTodayMovements();
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
          <h2>Pergerakan Stok Hari Ini</h2>
        </div>

        <Link
          href="/penerimaan"
          className="receiving-see-all"
        >
          Lihat Semua →
        </Link>
      </div>

      <div className="receiving-table-wrapper">
        <table className="receiving-dashboard-table">
          <thead>
            <tr>
              <th>No</th>
              <th>Nama Barang</th>
              <th>SKU</th>
              <th>Jumlah</th>
              <th>Jenis Transaksi</th>
              <th>Waktu</th>
              <th>Tujuan / Pemasok</th>
              <th>Status</th>
            </tr>
          </thead>

          <tbody>
            {loading && (
              <tr>
                <td colSpan={8}>
                  Memuat pergerakan stok hari ini...
                </td>
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
                  Belum ada pergerakan stok hari ini.
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

                  <td>
                    {formatNumber(Number(item.quantity) || 0)}{" "}
                    {item.unit || "unit"}
                  </td>

                  <td>
                    {item.type === "in"
                      ? "Stok Masuk"
                      : "Stok Keluar"}
                  </td>

                  <td>{formatDateTime(item.created_at)}</td>

                  <td>{getDestinationName(item)}</td>

                  <td>
                    <span className="status-received">
                      {item.type === "in"
                        ? "Diterima"
                        : "Dikeluarkan"}
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
