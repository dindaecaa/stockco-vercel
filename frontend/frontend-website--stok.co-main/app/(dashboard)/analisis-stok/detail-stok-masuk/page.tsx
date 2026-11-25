"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import ProfilManager from "@/components/profile/ProfilManager";
import { apiFetch } from "@/lib/api";

type Period = 3 | 6 | 9 | 12;

interface StockMovement {
  id?: number;
  product_id?: number;
  sku?: string;
  product_sku?: string;
  kode?: string;
  product_name?: string;
  nama_barang?: string;
  name?: string;
  category_name?: string;
  kategori?: string;
  category?: string;
  quantity?: number | string;
  type?: string;
  transaction_date?: string;
  created_at?: string;
  date?: string;
  supplier_name?: string;
  supplier?: string;
  pemasok?: string;
  note?: string;
}

interface DetailStockIn {
  id: string | number;
  tanggal: string;
  sku: string;
  nama: string;
  kategori: string;
  jumlah: number;
  pemasok: string;
  dateValue: Date;
}

function parseMovementDate(value: unknown): Date | null {
  if (!value) return null;

  const raw = String(value);

  const dateOnly = raw.match(/^(\d{4})-(\d{2})-(\d{2})$/);

  if (dateOnly) {
    return new Date(
      Number(dateOnly[1]),
      Number(dateOnly[2]) - 1,
      Number(dateOnly[3])
    );
  }

  const mysqlDateTime = raw.match(
    /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})/
  );

  if (mysqlDateTime) {
    return new Date(
      Number(mysqlDateTime[1]),
      Number(mysqlDateTime[2]) - 1,
      Number(mysqlDateTime[3]),
      Number(mysqlDateTime[4]),
      Number(mysqlDateTime[5]),
      Number(mysqlDateTime[6])
    );
  }

  const parsed = new Date(raw);

  return isNaN(parsed.getTime()) ? null : parsed;
}

function formatDate(date: Date): string {
  return date.toLocaleDateString("id-ID", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  });
}

function getMovementList(result: any): StockMovement[] {
  if (Array.isArray(result)) return result;

  if (Array.isArray(result?.data)) return result.data;

  if (Array.isArray(result?.data?.movements))
    return result.data.movements;

  if (Array.isArray(result?.data?.stockMovements))
    return result.data.stockMovements;

  if (Array.isArray(result?.data?.rows))
    return result.data.rows;

  if (Array.isArray(result?.movements))
    return result.movements;

  if (Array.isArray(result?.stockMovements))
    return result.stockMovements;

  return [];
}

function getPeriodStart(period: Period): Date {
  const now = new Date();

  return new Date(
    now.getFullYear(),
    now.getMonth() - period + 1,
    1
  );
}

function getPeriodLabel(period: Period): string {
  if (period === 3) return "3 Bulan Terakhir";
  if (period === 6) return "6 Bulan Terakhir";
  if (period === 9) return "9 Bulan Terakhir";

  return "1 Tahun Terakhir";
}

function getDateRangeText(period: Period): string {
  const start = getPeriodStart(period);
  const end = new Date();

  const startText = start.toLocaleDateString("id-ID", {
    month: "long",
    year: "numeric",
  });

  const endText = end.toLocaleDateString("id-ID", {
    month: "long",
    year: "numeric",
  });

  return `${startText} - ${endText}`;
}

function mapMovement(
  movement: StockMovement,
  index: number
): DetailStockIn | null {
  const date = parseMovementDate(
    movement.transaction_date ??
      movement.created_at ??
      movement.date
  );

  if (!date || isNaN(date.getTime())) return null;

  const quantity = Number(movement.quantity ?? 0);

  return {
    id: movement.id ?? `${movement.product_id ?? "item"}-${index}`,
    tanggal: formatDate(date),
    sku: String(
      movement.sku ??
        movement.product_sku ??
        movement.kode ??
        "-"
    ),
    nama: String(
      movement.product_name ??
        movement.nama_barang ??
        movement.name ??
        "-"
    ),
    kategori: String(
      movement.category_name ??
        movement.kategori ??
        movement.category ??
        "-"
    ),
    jumlah: Number.isFinite(quantity) ? quantity : 0,
    pemasok: String(
      movement.supplier_name ??
        movement.supplier ??
        movement.pemasok ??
        "-"
    ),
    dateValue: date,
  };
}

export default function DetailStokMasukPage() {
  const searchParams = useSearchParams();

  const periodParam = Number(searchParams.get("period"));

  const initialPeriod: Period =
    periodParam === 3 ||
    periodParam === 6 ||
    periodParam === 9 ||
    periodParam === 12
      ? (periodParam as Period)
      : 6;

  const [period, setPeriod] = useState<Period>(initialPeriod);

  const [activeCard, setActiveCard] = useState<
    "barang" | "transaksi" | "periode"
  >("barang");

  const [showPeriodOptions, setShowPeriodOptions] =
    useState(false);

  const [movements, setMovements] = useState<StockMovement[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;

    async function loadMovements() {
      try {
        setLoading(true);
        setError("");

        const response = await apiFetch("stock-movements", {
          method: "GET",
          cache: "no-store",
        });

        const result = await response.json();

        if (!response.ok || result.success === false) {
          throw new Error(
            result.message || "Gagal mengambil data stok masuk."
          );
        }

        const list = getMovementList(result);

        if (!cancelled) {
          setMovements(list);
        }
      } catch (err) {
        if (!cancelled) {
          setError(
            err instanceof Error
              ? err.message
              : "Terjadi kesalahan saat mengambil data stok masuk."
          );
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    loadMovements();

    return () => {
      cancelled = true;
    };
  }, []);

  const dataStokMasuk = useMemo(() => {
    return movements
      .filter(
        (movement) =>
          String(movement.type).toLowerCase() === "in"
      )
      .map(mapMovement)
      .filter(
        (item): item is DetailStockIn => item !== null
      )
      .sort(
        (a, b) =>
          b.dateValue.getTime() - a.dateValue.getTime()
      );
  }, [movements]);

  const dataTampil = useMemo(() => {
    const startDate = getPeriodStart(period);
    const now = new Date();

    return dataStokMasuk.filter(
      (item) =>
        item.dateValue >= startDate &&
        item.dateValue <= now
    );
  }, [dataStokMasuk, period]);

  const totalBarang = dataTampil.reduce(
    (total, item) => total + item.jumlah,
    0
  );

  const jumlahTransaksi = dataTampil.length;

  const handlePeriodChange = (newPeriod: Period) => {
    setPeriod(newPeriod);
    setShowPeriodOptions(false);
    setActiveCard("periode");
  };

  return (
    <main className="detail-stok-page">
      <section className="detail-stok-content">
        {/* HEADER */}
        <header className="detail-stok-header">
          <div>
            <Link
              href="/analisis-stok"
              className="back-to-analisis"
            >
              ← Kembali ke Analisis Stok
            </Link>

            <h1>Detail Stok Masuk</h1>

            <p>
              Rincian penerimaan barang berdasarkan data stok masuk.
            </p>
          </div>

          <div className="detail-header-right">
            <span className="detail-period-text">
              {getPeriodLabel(period)}
            </span>

            <ProfilManager />
          </div>
        </header>

        {/* RINGKASAN */}
        <section className="detail-summary">
          {/* TOTAL BARANG */}
          <button
            type="button"
            className={`detail-summary-card green ${
              activeCard === "barang" ? "summary-active" : ""
            }`}
            onClick={() => {
              setActiveCard("barang");
              setShowPeriodOptions(false);
            }}
          >
            <span>Total Barang Masuk</span>

            <strong>{loading ? "..." : totalBarang}</strong>

            <small>unit</small>
          </button>

          {/* JUMLAH TRANSAKSI */}
          <button
            type="button"
            className={`detail-summary-card ${
              activeCard === "transaksi" ? "summary-active" : ""
            }`}
            onClick={() => {
              setActiveCard("transaksi");
              setShowPeriodOptions(false);
            }}
          >
            <span>Jumlah Transaksi</span>

            <strong>{loading ? "..." : jumlahTransaksi}</strong>

            <small>transaksi penerimaan</small>
          </button>

          {/* PERIODE */}
          <div className="period-card-wrapper">
            <button
              type="button"
              className={`detail-summary-card ${
                activeCard === "periode" ? "summary-active" : ""
              }`}
              onClick={() => {
                setActiveCard("periode");
                setShowPeriodOptions(!showPeriodOptions);
              }}
            >
              <span>Periode</span>

              <strong>{period}</strong>

              <small>Bulan Terakhir</small>
            </button>

            {/* PILIHAN PERIODE */}
            {showPeriodOptions && (
              <div className="period-options">
                {[3, 6, 9, 12].map((value) => (
                  <button
                    type="button"
                    key={value}
                    onClick={() =>
                      handlePeriodChange(value as Period)
                    }
                    className={
                      period === value
                        ? "period-option-active"
                        : ""
                    }
                  >
                    {value === 12 ? "1 Tahun" : `${value} Bulan`}
                  </button>
                ))}
              </div>
            )}
          </div>
        </section>

        {/* TABEL */}
        <section className="detail-table-card">
          <div className="detail-table-header">
            <div>
              <h2>Rincian Stok Masuk</h2>

              <p>
                Daftar barang yang diterima di gudang.
              </p>
            </div>

            <span className="table-period">
              {getDateRangeText(period)}
            </span>
          </div>

          {error && (
            <div className="empty-table">
              {error}
            </div>
          )}

          <div className="table-wrapper">
            <table className="stok-detail-table">
              <thead>
                <tr>
                  <th>No</th>
                  <th>Tanggal</th>
                  <th>Kode SKU</th>
                  <th>Nama Barang</th>
                  <th>Kategori</th>
                  <th>Jumlah</th>
                  <th>Pemasok</th>
                </tr>
              </thead>

              <tbody>
                {!loading &&
                  !error &&
                  dataTampil.map((item, index) => (
                    <tr key={item.id}>
                      <td>{index + 1}</td>

                      <td>{item.tanggal}</td>

                      <td>
                        <span className="sku-badge">
                          {item.sku}
                        </span>
                      </td>

                      <td className="barang-name">
                        {item.nama}
                      </td>

                      <td>
                        <span className="kategori-badge">
                          {item.kategori}
                        </span>
                      </td>

                      <td>
                        <strong className="jumlah-masuk">
                          +{item.jumlah}
                        </strong>
                      </td>

                      <td>{item.pemasok}</td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>

          {loading && (
            <div className="empty-table">
              Memuat data stok masuk dari database...
            </div>
          )}

          {!loading &&
            !error &&
            dataTampil.length === 0 && (
              <div className="empty-table">
                Belum ada data stok masuk pada periode ini.
              </div>
            )}
        </section>
      </section>
    </main>
  );
}