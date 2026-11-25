
"use client";

import { useEffect, useState } from "react";
import { ChevronDown } from "lucide-react";

import { apiFetch } from "@/lib/api";

type Period = 3 | 6 | 12;

type StockData = {
  month_key: string;
  month: string;
  stock_in: number;
  stock_out: number;
};

interface DashboardChartResponse {
  success: boolean;
  message?: string;
  data?: {
    period: Period;
    data: StockData[];
  };
}

const periods: { value: Period; label: string }[] = [
  { value: 3, label: "3 Bulan Terakhir" },
  { value: 6, label: "6 Bulan Terakhir" },
  { value: 12, label: "1 Tahun" },
];

const chartWidth = 760;
const chartHeight = 270;
const left = 42;
const right = 12;
const top = 18;
const bottom = 35;

const plotWidth = chartWidth - left - right;
const plotHeight = chartHeight - top - bottom;
const baseline = top + plotHeight;

const formatNumber = (value: number) =>
  new Intl.NumberFormat("id-ID").format(value);

function getY(value: number, maxValue: number) {
  return baseline - (value / maxValue) * plotHeight;
}

function getPoints(
  data: StockData[],
  key: "stock_in" | "stock_out",
  maxValue: number
) {
  return data.map((item, index) => ({
    x: left + (index * plotWidth) / Math.max(data.length - 1, 1),
    y: getY(item[key], maxValue),
    month: item.month,
    monthKey: item.month_key,
    value: item[key],
  }));
}

function smoothPath(points: { x: number; y: number }[]) {
  if (!points.length) return "";

  if (points.length === 1) {
    return `M ${points[0].x} ${points[0].y}`;
  }

  return points.reduce((path, point, index) => {
    if (index === 0) {
      return `M ${point.x} ${point.y}`;
    }

    const previous = points[index - 1];
    const midX = (previous.x + point.x) / 2;

    return (
      path +
      ` C ${midX} ${previous.y}, ${midX} ${point.y}, ${point.x} ${point.y}`
    );
  }, "");
}

function areaPath(
  points: { x: number; y: number }[]
) {
  if (!points.length) return "";

  return (
    smoothPath(points) +
    ` L ${points[points.length - 1].x} ${baseline}` +
    ` L ${points[0].x} ${baseline} Z`
  );
}

export default function StockChart() {
  const [period, setPeriod] = useState<Period>(6);
  const [showDropdown, setShowDropdown] = useState(false);
  const [selectedMonth, setSelectedMonth] = useState<string | null>(null);

  const [data, setData] = useState<StockData[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const controller = new AbortController();

    const fetchStockMovements = async () => {
      try {
        setLoading(true);
        setError("");

        const response = await apiFetch(
          `dashboard/stock-movements?period=${period}`,
          {
            method: "GET",
            cache: "no-store",
            signal: controller.signal,
          }
        );

        const result: DashboardChartResponse =
          await response.json();

        if (
          !response.ok ||
          !result.success ||
          !result.data ||
          !Array.isArray(result.data.data)
        ) {
          throw new Error(
            result.message || "Gagal mengambil data grafik stok."
          );
        }

        if (!controller.signal.aborted) {
          setData(result.data.data);
        }
      } catch (err) {
        if (controller.signal.aborted) return;

        setData([]);

        setError(
          err instanceof Error
            ? err.message
            : "Terjadi kesalahan saat mengambil data grafik."
        );
      } finally {
        if (!controller.signal.aborted) {
          setLoading(false);
        }
      }
    };

    fetchStockMovements();

    return () => {
      controller.abort();
    };
  }, [period]);

  const selectedPeriod =
    periods.find((item) => item.value === period)?.label ??
    "6 Bulan Terakhir";

  const highestValue = Math.max(
    0,
    ...data.map((item) =>
      Math.max(item.stock_in, item.stock_out)
    )
  );

  const maxValue = Math.max(
    20,
    Math.ceil(highestValue / 20) * 20
  );

  const ticks = Array.from(
    { length: 5 },
    (_, index) => (maxValue / 4) * index
  );

  const masukPoints = getPoints(data, "stock_in", maxValue);
  const keluarPoints = getPoints(data, "stock_out", maxValue);

  const selectedData = data.find(
    (item) => item.month_key === selectedMonth
  );

  const hasMovement = data.some(
    (item) => item.stock_in > 0 || item.stock_out > 0
  );

  return (
    <section className="stock-chart-card">
      <div className="stock-chart-header">
        <div className="stock-chart-heading">
          <h2>Pergerakan Stok</h2>
          <p className="stock-chart-subtitle">
            Ringkasan stok masuk dan keluar
          </p>
        </div>

        <div className="stock-chart-controls">
          <div className="stock-chart-legend">
            <span>
              <i className="stock-legend-dot stock-legend-in" />
              Stok Masuk
            </span>

            <span>
              <i className="stock-legend-dot stock-legend-out" />
              Stok Keluar
            </span>
          </div>

          <div className="stock-period-wrapper">
            <button
              type="button"
              className="stock-period-button"
              aria-expanded={showDropdown}
              onClick={() => setShowDropdown((value) => !value)}
            >
              {selectedPeriod}

              <ChevronDown
                size={15}
                className={showDropdown ? "rotate-arrow" : ""}
              />
            </button>

            {showDropdown && (
              <div className="stock-period-menu">
                {periods.map((option) => (
                  <button
                    key={option.value}
                    type="button"
                    className={
                      period === option.value ? "selected" : ""
                    }
                    onClick={() => {
                      setPeriod(option.value);
                      setSelectedMonth(null);
                      setShowDropdown(false);
                    }}
                  >
                    {option.label}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="stock-chart-visual">
        {loading ? (
          <p
            className="stock-chart-status"
            role="status"
          >
            Memuat data pergerakan stok...
          </p>
        ) : error ? (
          <p
            className="stock-chart-status"
            role="alert"
          >
            {error}
          </p>
        ) : (
          <>
            <svg
              className="stock-chart-svg"
              viewBox={`0 0 ${chartWidth} ${chartHeight}`}
              role="img"
              aria-label={`Grafik stok masuk dan keluar, ${selectedPeriod}`}
            >
              <defs>
                <linearGradient
                  id="stockInGradient"
                  x1="0"
                  y1="0"
                  x2="0"
                  y2="1"
                >
                  <stop
                    offset="0%"
                    stopColor="#239966"
                    stopOpacity="0.19"
                  />
                  <stop
                    offset="100%"
                    stopColor="#239966"
                    stopOpacity="0.01"
                  />
                </linearGradient>

                <linearGradient
                  id="stockOutGradient"
                  x1="0"
                  y1="0"
                  x2="0"
                  y2="1"
                >
                  <stop
                    offset="0%"
                    stopColor="#f5ae38"
                    stopOpacity="0.15"
                  />
                  <stop
                    offset="100%"
                    stopColor="#f5ae38"
                    stopOpacity="0.01"
                  />
                </linearGradient>
              </defs>

              {/* Garis grid dan angka sumbu Y */}
              {ticks.map((tick) => {
                const y = getY(tick, maxValue);

                return (
                  <g key={tick}>
                    <line
                      x1={left}
                      y1={y}
                      x2={chartWidth - right}
                      y2={y}
                      className="stock-chart-grid-line"
                    />

                    <text
                      x={left - 10}
                      y={y + 4}
                      textAnchor="end"
                      className="stock-chart-axis-label"
                    >
                      {formatNumber(tick)}
                    </text>
                  </g>
                );
              })}

              {/* Area stok masuk dan keluar */}
              <path
                d={areaPath(masukPoints)}
                fill="url(#stockInGradient)"
                className="stock-chart-area"
              />

              <path
                d={areaPath(keluarPoints)}
                fill="url(#stockOutGradient)"
                className="stock-chart-area"
              />

              {/* Garis stok masuk */}
              <path
                d={smoothPath(masukPoints)}
                className="stock-line stock-line-in"
              />

              {/* Garis stok keluar */}
              <path
                d={smoothPath(keluarPoints)}
                className="stock-line stock-line-out"
              />

              {/* Titik data stok masuk */}
              {masukPoints.map((point) => {
                const active =
                  selectedMonth === point.monthKey;

                return (
                  <g
                    key={`in-${point.monthKey}`}
                    className="stock-point-group"
                    tabIndex={0}
                    role="button"
                    aria-label={`${point.month}, stok masuk ${formatNumber(point.value)}`}
                    onMouseEnter={() =>
                      setSelectedMonth(point.monthKey)
                    }
                    onMouseLeave={() =>
                      setSelectedMonth(null)
                    }
                    onFocus={() =>
                      setSelectedMonth(point.monthKey)
                    }
                    onBlur={() =>
                      setSelectedMonth(null)
                    }
                    onClick={() =>
                      setSelectedMonth((current) =>
                        current === point.monthKey
                          ? null
                          : point.monthKey
                      )
                    }
                    onKeyDown={(event) => {
                      if (
                        event.key === "Enter" ||
                        event.key === " "
                      ) {
                        event.preventDefault();

                        setSelectedMonth((current) =>
                          current === point.monthKey
                            ? null
                            : point.monthKey
                        );
                      }
                    }}
                  >
                    <circle
                      cx={point.x}
                      cy={point.y}
                      r="12"
                      fill="transparent"
                    />

                    <circle
                      cx={point.x}
                      cy={point.y}
                      r={active ? 5 : 3.5}
                      className="stock-point stock-point-in"
                    />
                  </g>
                );
              })}

              {/* Titik data stok keluar */}
              {keluarPoints.map((point) => {
                const active =
                  selectedMonth === point.monthKey;

                return (
                  <g
                    key={`out-${point.monthKey}`}
                    className="stock-point-group"
                    tabIndex={0}
                    role="button"
                    aria-label={`${point.month}, stok keluar ${formatNumber(point.value)}`}
                    onMouseEnter={() =>
                      setSelectedMonth(point.monthKey)
                    }
                    onMouseLeave={() =>
                      setSelectedMonth(null)
                    }
                    onFocus={() =>
                      setSelectedMonth(point.monthKey)
                    }
                    onBlur={() =>
                      setSelectedMonth(null)
                    }
                    onClick={() =>
                      setSelectedMonth((current) =>
                        current === point.monthKey
                          ? null
                          : point.monthKey
                      )
                    }
                    onKeyDown={(event) => {
                      if (
                        event.key === "Enter" ||
                        event.key === " "
                      ) {
                        event.preventDefault();

                        setSelectedMonth((current) =>
                          current === point.monthKey
                            ? null
                            : point.monthKey
                        );
                      }
                    }}
                  >
                    <circle
                      cx={point.x}
                      cy={point.y}
                      r="12"
                      fill="transparent"
                    />

                    <circle
                      cx={point.x}
                      cy={point.y}
                      r={active ? 5 : 3.5}
                      className="stock-point stock-point-out"
                    />
                  </g>
                );
              })}

              {/* Label bulan */}
              {data.map((item, index) => {
                const x =
                  left +
                  (index * plotWidth) /
                    Math.max(data.length - 1, 1);

                return (
                  <text
                    key={item.month_key}
                    x={x}
                    y={baseline + 22}
                    textAnchor="middle"
                    className={
                      selectedMonth === item.month_key
                        ? "stock-chart-month-label active"
                        : "stock-chart-month-label"
                    }
                  >
                    {item.month}
                  </text>
                );
              })}

              {/* Garis vertikal bulan terpilih */}
              {selectedData && (
                <line
                  x1={
                    left +
                    (data.findIndex(
                      (item) =>
                        item.month_key === selectedMonth
                    ) *
                      plotWidth) /
                      Math.max(data.length - 1, 1)
                  }
                  x2={
                    left +
                    (data.findIndex(
                      (item) =>
                        item.month_key === selectedMonth
                    ) *
                      plotWidth) /
                      Math.max(data.length - 1, 1)
                  }
                  y1={top}
                  y2={baseline}
                  className="stock-chart-crosshair"
                />
              )}
            </svg>

            {/* Detail interaktif */}
            {selectedData && (
              <div
                className="stock-chart-detail"
                aria-live="polite"
              >
                <strong>{selectedData.month}</strong>

                <span>
                  <i className="stock-legend-dot stock-legend-in" />
                  Masuk:{" "}
                  <b>{formatNumber(selectedData.stock_in)}</b>
                </span>

                <span>
                  <i className="stock-legend-dot stock-legend-out" />
                  Keluar:{" "}
                  <b>{formatNumber(selectedData.stock_out)}</b>
                </span>
              </div>
            )}

            {!hasMovement && (
              <p className="stock-chart-status">
                Belum ada transaksi stok pada periode ini.
              </p>
            )}
          </>
        )}
      </div>

      <div className="stock-chart-footer">
        <span>Data pergerakan stok bulanan</span>
        <span>Jumlah dalam unit</span>
      </div>
    </section>
  );
}
