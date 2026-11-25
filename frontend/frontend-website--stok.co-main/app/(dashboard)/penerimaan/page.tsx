"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";

import { apiFetch } from "@/lib/api";

interface MovementItem {
  id: number;
  product_id: number;
  type: "in" | "out";
  product_name: string;
  product_sku: string | null;
  supplier_name: string | null;
  customer_name: string | null;
  quantity: number;
  transaction_date: string | null;
  note: string | null;
  created_at: string | null;
  unit?: string | null;
}

interface ApiResponse {
  success?: boolean;
  message?: string;
  data?: unknown;
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat("id-ID").format(value);
}

function parseDate(value: string | null): Date | null {
  if (!value) return null;

  // Format timestamp MySQL: YYYY-MM-DD HH:mm:ss
  const normalized = value.includes("T")
    ? value
    : value.replace(" ", "T");

  const date = new Date(normalized);

  return Number.isNaN(date.getTime()) ? null : date;
}

function formatDateTime(value: string | null): string {
  const date = parseDate(value);

  if (!date) return "—";

  return new Intl.DateTimeFormat("id-ID", {
    timeZone: "Asia/Jakarta",
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  })
    .format(date)
    .replace(".", ".");
}

function getMovementArray(result: ApiResponse): MovementItem[] {
  const rawData = result.data;

  let items: unknown[] = [];

  if (Array.isArray(rawData)) {
    items = rawData;
  } else if (rawData && typeof rawData === "object") {
    const nested = rawData as Record<string, unknown>;

    if (Array.isArray(nested.data)) {
      items = nested.data;
    } else if (Array.isArray(nested.movements)) {
      items = nested.movements;
    }
  }

  return items as MovementItem[];
}

export default function PenerimaanPage() {
  const [data, setData] = useState<MovementItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const controller = new AbortController();

    async function fetchMovements() {
      try {
        setLoading(true);
        setError("");

        const response = await apiFetch("stock-movements", {
          method: "GET",
          cache: "no-store",
          signal: controller.signal,
        });

        const result: ApiResponse = await response.json();

        if (
          !response.ok ||
          result.success === false ||
          !Array.isArray(result.data)
        ) {
          throw new Error(
            result.message ||
              "Gagal mengambil data pergerakan stok."
          );
        }

        const movements = getMovementArray(result);

        // Ambil semua transaksi stok masuk dan stok keluar
        const allMovements = movements.filter(
          (item) =>
            item.type === "in" ||
            item.type === "out"
        );

        // Urutkan transaksi terbaru terlebih dahulu
        allMovements.sort((a, b) => {
          const dateA = parseDate(a.created_at)?.getTime() ?? 0;
          const dateB = parseDate(b.created_at)?.getTime() ?? 0;

          return dateB - dateA;
        });

        if (!controller.signal.aborted) {
          setData(allMovements);
        }
      } catch (err) {
        if (controller.signal.aborted) return;

        setError(
          err instanceof Error
            ? err.message
            : "Terjadi kesalahan saat mengambil riwayat stok."
        );
      } finally {
        if (!controller.signal.aborted) {
          setLoading(false);
        }
      }
    }

    fetchMovements();

    return () => {
      controller.abort();
    };
  }, []);

  const totalData = useMemo(() => data.length, [data]);

  return (
    <main className="dashboard-page">
      {/* MAIN CONTENT */}
      <section className="dashboard-content">
        {/* HEADER */}
        <div className="penerimaan-page-topbar">
          <div className="penerimaan-title">
            <Link
              href="/dashboard"
              className="penerimaan-back-button"
            >
              ←
            </Link>

            <div>
              <h1>Riwayat Pergerakan Stok</h1>

              <p>
                Daftar lengkap transaksi stok masuk dan stok keluar
                yang tercatat di sistem.
              </p>
            </div>
          </div>
        </div>

        {/* CARD TABLE */}
        <div className="penerimaan-full-card">
          <div className="penerimaan-card-header">
            <div>
              <h2>Semua Transaksi Stok</h2>

              <p>
                Menampilkan seluruh riwayat pergerakan inventori.
              </p>
            </div>

            <div className="penerimaan-total">
              <span>Total Transaksi</span>

              <strong>
                {loading ? "..." : formatNumber(totalData)}
              </strong>
            </div>
          </div>

          {/* TABLE */}
          <div className="table-wrapper">
            <table>
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
                {/* LOADING */}
                {loading && (
                  <tr>
                    <td colSpan={8}>
                      Memuat seluruh riwayat pergerakan stok...
                    </td>
                  </tr>
                )}

                {/* ERROR */}
                {!loading && error && (
                  <tr>
                    <td colSpan={8} role="alert">
                      {error}
                    </td>
                  </tr>
                )}

                {/* EMPTY DATA */}
                {!loading && !error && data.length === 0 && (
                  <tr>
                    <td colSpan={8}>
                      Belum ada riwayat pergerakan stok.
                    </td>
                  </tr>
                )}

                {/* DATABASE DATA */}
                {!loading &&
                  !error &&
                  data.map((item, index) => (
                    <tr key={item.id}>
                      <td>{index + 1}</td>

                      <td>
                        {item.product_name || "—"}
                      </td>

                      <td>
                        {item.product_sku || "—"}
                      </td>

                      <td>
                        {formatNumber(
                          Number(item.quantity) || 0
                        )}{" "}
                        {item.unit || "unit"}
                      </td>

                      {/* JENIS TRANSAKSI */}
                      <td>
                        {item.type === "in"
                          ? "Stok Masuk"
                          : "Stok Keluar"}
                      </td>

                      {/* WAKTU */}
                      <td>
                        {formatDateTime(
                          item.created_at ||
                            item.transaction_date
                        )}
                      </td>

                      {/* SUPPLIER / CUSTOMER */}
                      <td>
                        {item.type === "in"
                          ? item.supplier_name || "—"
                          : item.customer_name || "—"}
                      </td>

                      {/* STATUS */}
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
        </div>
      </section>
    </main>
  );
}