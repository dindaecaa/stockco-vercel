"use client";

import Link from "next/link";
import ProfilManager from "@/components/profile/ProfilManager";
import { apiFetch } from "@/lib/api";
import { useEffect, useMemo, useState } from "react";

type Period = 3 | 6 | 9 | 12;
type MovementType = "masuk" | "keluar";

interface StockMovement {
  id?: number;
  type?: string;
  quantity?: number | string;
  transaction_date?: string;
  created_at?: string;
  date?: string;
  movement_date?: string;
  product_name?: string;
  sku?: string;
}

interface MonthlyData {
  bulan: string;
  jumlah: number;
  tahun: number;
}

const MONTH_NAMES = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "Mei",
  "Jun",
  "Jul",
  "Agu",
  "Sep",
  "Okt",
  "Nov",
  "Des",
];

const MONTH_NAMES_FULL = [
  "Januari",
  "Februari",
  "Maret",
  "April",
  "Mei",
  "Juni",
  "Juli",
  "Agustus",
  "September",
  "Oktober",
  "November",
  "Desember",
];

// ==========================================
// HELPERS
// ==========================================

function getMovementList(result: any): StockMovement[] {
  if (Array.isArray(result)) {
    return result;
  }

  if (Array.isArray(result?.data)) {
    return result.data;
  }

  if (Array.isArray(result?.data?.data)) {
    return result.data.data;
  }

  if (Array.isArray(result?.movements)) {
    return result.movements;
  }

  if (Array.isArray(result?.stockMovements)) {
    return result.stockMovements;
  }

  return [];
}

function parseMovementDate(movement: StockMovement): Date | null {
  const rawDate =
    movement.transaction_date ??
    movement.movement_date ??
    movement.created_at ??
    movement.date;

  if (!rawDate) return null;

  // MySQL DATETIME: diperlakukan sebagai waktu lokal
  if (
    typeof rawDate === "string" &&
    /^\d{4}-\d{2}-\d{2}(?:\s+\d{2}:\d{2}:\d{2})?$/.test(
      rawDate
    )
  ) {
    const [datePart, timePart = "00:00:00"] = rawDate.split(" ");

    const [year, month, day] = datePart
      .split("-")
      .map(Number);

    const [hour, minute, second] = timePart
      .split(":")
      .map(Number);

    const parsed = new Date(
      year,
      month - 1,
      day,
      hour || 0,
      minute || 0,
      second || 0
    );

    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  const parsed = new Date(rawDate);

  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function normalizeMovementType(type?: string): MovementType | null {
  const normalized = String(type ?? "")
    .toLowerCase()
    .trim();

  if (
    ["in", "masuk", "stock_in", "stock-in"].includes(
      normalized
    )
  ) {
    return "masuk";
  }

  if (
    ["out", "keluar", "stock_out", "stock-out"].includes(
      normalized
    )
  ) {
    return "keluar";
  }

  return null;
}

function getPeriodMonths(period: Period, endDate: Date) {
  const result: {
    bulan: string;
    tahun: number;
    monthIndex: number;
  }[] = [];

  for (let i = period - 1; i >= 0; i--) {
    const date = new Date(
      endDate.getFullYear(),
      endDate.getMonth() - i,
      1
    );

    result.push({
      bulan: MONTH_NAMES[date.getMonth()],
      tahun: date.getFullYear(),
      monthIndex: date.getMonth(),
    });
  }

  return result;
}

function getNamaRentang(period: Period, endDate: Date) {
  const startDate = new Date(
    endDate.getFullYear(),
    endDate.getMonth() - period + 1,
    1
  );

  const startMonth = MONTH_NAMES[startDate.getMonth()];
  const endMonth = MONTH_NAMES[endDate.getMonth()];

  if (startDate.getFullYear() === endDate.getFullYear()) {
    return `${startMonth} - ${endMonth} ${endDate.getFullYear()}`;
  }

  return `${startMonth} ${startDate.getFullYear()} - ${endMonth} ${endDate.getFullYear()}`;
}

function getPercentageChange(
  currentTotal: number,
  previousTotal: number
) {
  if (previousTotal === 0) {
    if (currentTotal === 0) return 0;
    return 100;
  }

  return Math.round(
    ((currentTotal - previousTotal) / previousTotal) * 100
  );
}

// ==========================================
// MAIN PAGE
// ==========================================

export default function AnalisisStokPage() {
  const [period, setPeriod] = useState<Period>(6);
  const [movements, setMovements] = useState<StockMovement[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let isMounted = true;

    async function fetchMovements() {
      try {
        setLoading(true);
        setError("");

        const response = await apiFetch("stock-movements", {
          method: "GET",
          cache: "no-store",
        });

        if (!response.ok) {
          throw new Error("Gagal mengambil data transaksi stok.");
        }

        const result = await response.json();
        const movementList = getMovementList(result);

        if (isMounted) {
          setMovements(movementList);
        }
      } catch (err) {
        console.error("Error Analisis Stok:", err);

        if (isMounted) {
          setError(
            err instanceof Error
              ? err.message
              : "Terjadi kesalahan saat mengambil data stok."
          );
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    }

    fetchMovements();

    return () => {
      isMounted = false;
    };
  }, []);

  // ==========================================
  // DATA STOK MASUK & KELUAR DARI DATABASE
  // ==========================================

  const dataStokMasuk = useMemo(() => {
    return movements.filter(
      (movement) => normalizeMovementType(movement.type) === "masuk"
    );
  }, [movements]);

  const dataStokKeluar = useMemo(() => {
    return movements.filter(
      (movement) => normalizeMovementType(movement.type) === "keluar"
    );
  }, [movements]);

  return (
    <main className="analisis-page">
      <section className="analisis-content">

        {/* HEADER */}
        <header className="analisis-header">
          <div className="analisis-header-left">
            <h1>Analisis Stok</h1>

            <p>
              Lihat tren penerimaan dan pengeluaran barang di gudang.
            </p>
          </div>

          <div className="analisis-header-right">
            <select
              className="date-filter-select"
              value={period}
              onChange={(e) =>
                setPeriod(Number(e.target.value) as Period)
              }
            >
              <option value={3}>3 Bulan Terakhir</option>
              <option value={6}>6 Bulan Terakhir</option>
              <option value={9}>9 Bulan Terakhir</option>
              <option value={12}>12 Bulan Terakhir</option>
            </select>

            <ProfilManager />
          </div>
        </header>

        {/* ERROR */}
        {error && (
          <div className="analisis-error">
            {error}
          </div>
        )}

        {/* LOADING */}
        {loading ? (
          <div className="analisis-loading">
            Memuat data analisis stok...
          </div>
        ) : (
          <>
            {/* STOK MASUK */}
            <StockChart
              title="Stok Masuk"
              movements={dataStokMasuk}
              type="masuk"
              period={period}
              setPeriod={setPeriod}
              detailLink="/analisis-stok/detail-stok-masuk"
              detailText="Detail Stok Masuk"
            />

            {/* STOK KELUAR */}
            <StockChart
              title="Stok Keluar"
              movements={dataStokKeluar}
              type="keluar"
              period={period}
              setPeriod={setPeriod}
              detailLink="/analisis-stok/detail-stok-keluar"
              detailText="Detail Stok Keluar"
            />
          </>
        )}

      </section>
    </main>
  );
}

// ==========================================
// STOCK CHART
// ==========================================

function StockChart({
  title,
  movements,
  type,
  period,
  setPeriod,
  detailLink,
  detailText,
}: {
  title: string;
  movements: StockMovement[];
  type: MovementType;
  period: Period;
  setPeriod: (period: Period) => void;
  detailLink: string;
  detailText: string;
}) {
  const now = new Date();

  // ==========================================
  // BULAN YANG DITAMPILKAN
  // ==========================================

  const dataTampil: MonthlyData[] = useMemo(() => {
    const months = getPeriodMonths(period, now);

    return months.map((month) => {
      const jumlah = movements.reduce((total, movement) => {
        const date = parseMovementDate(movement);

        if (!date) return total;

        if (
          date.getMonth() === month.monthIndex &&
          date.getFullYear() === month.tahun
        ) {
          return total + (Number(movement.quantity) || 0);
        }

        return total;
      }, 0);

      return {
        bulan: month.bulan,
        tahun: month.tahun,
        jumlah,
      };
    });
  }, [movements, period]);

  // ==========================================
  // TOTAL PERIODE AKTIF
  // ==========================================

  const totalPeriode = dataTampil.reduce(
    (total, item) => total + item.jumlah,
    0
  );

  // ==========================================
  // PERBANDINGAN PERIODE SEBELUMNYA
  // Membandingkan rentang bulan yang sama
  // ==========================================

  const previousStart = new Date(
    now.getFullYear(),
    now.getMonth() - period * 2 + 1,
    1
  );

  const previousEnd = new Date(
    now.getFullYear(),
    now.getMonth() - period + 1,
    1
  );

  const totalSebelumnya = movements.reduce(
    (total, movement) => {
      const date = parseMovementDate(movement);

      if (!date) return total;

      if (date >= previousStart && date < previousEnd) {
        return total + (Number(movement.quantity) || 0);
      }

      return total;
    },
    0
  );

  // ==========================================
  // PERSENTASE PERUBAHAN
  // ==========================================

  const persentase = getPercentageChange(
    totalPeriode,
    totalSebelumnya
  );

  const percentageText =
    persentase > 0
      ? `+${persentase}%`
      : `${persentase}%`;

  // ==========================================
  // SKALA CHART
  // ==========================================

  const maxValue = Math.max(
    ...dataTampil.map((item) => item.jumlah),
    1
  );

  return (
    <section className={`stock-chart-card ${type}`}>

      {/* HEADER CARD */}
      <div className="stock-chart-header">
        <div className="stock-chart-title">
          <h2>{title}</h2>

          <select
            className="chart-period-select"
            value={period}
            onChange={(e) =>
              setPeriod(Number(e.target.value) as Period)
            }
          >
            <option value={3}>3 Bulan Terakhir</option>
            <option value={6}>6 Bulan Terakhir</option>
            <option value={9}>9 Bulan Terakhir</option>
            <option value={12}>1 Tahun Terakhir</option>
          </select>
        </div>

        <Link
          href={`${detailLink}?period=${period}`}
          className="chart-detail-link"
        >
          {detailText}

          <span className="chart-detail-arrow">
            →
          </span>
        </Link>
      </div>

      {/* INFO PERIODE */}
      <div className="chart-selected-period">
        Menampilkan data:{" "}
        <strong>
          {getNamaRentang(period, now)}
        </strong>
      </div>

      <div className="stock-chart-body">

        {/* CHART */}
        <div className="chart">
          <div className="chart-y-axis">
            <span>{maxValue}</span>
            <span>{Math.round(maxValue * 0.75)}</span>
            <span>{Math.round(maxValue * 0.5)}</span>
            <span>{Math.round(maxValue * 0.25)}</span>
            <span>0</span>
          </div>

          <div className="chart-area">
            <div className="chart-grid">
              <span></span>
              <span></span>
              <span></span>
              <span></span>
              <span></span>
            </div>

            <div className="bars">
              {dataTampil.map((item, index) => (
                <div
                  className={`bar ${type}`}
                  key={`${item.bulan}-${item.tahun}-${index}`}
                  style={{
                    height: `${Math.max(
                      (item.jumlah / maxValue) * 200,
                      5
                    )}px`,
                    flex: "0 0 auto",
                    width: `calc(100% / ${dataTampil.length} - 12px)`,
                  }}
                >
                  <span className="bar-value">
                    {item.jumlah}
                  </span>

                  <span className="bar-label">
                    {item.bulan}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* TOTAL CARD */}
        <Link
          href={`${detailLink}?period=${period}`}
          className={`stock-summary ${type}`}
        >
          <div className="summary-icon">
            {type === "masuk" ? "↗" : "↘"}
          </div>

          <p className="summary-title">
            Total Stok{" "}
            {type === "masuk" ? "Masuk" : "Keluar"}
          </p>

          <h3>
            {totalPeriode}
            <span> unit</span>
          </h3>

          <p className="summary-percentage">
            {percentageText}
          </p>

          <p className="summary-description">
            dibandingkan data sebelumnya
          </p>

          <div className="summary-illustration">
            {type === "masuk" ? "📦" : "📤"}
          </div>

          <span className="summary-click-text">
            Klik untuk melihat detail →
          </span>
        </Link>

      </div>
    </section>
  );
}