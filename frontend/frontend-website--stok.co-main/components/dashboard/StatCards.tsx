"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  Package,
  Database,
  AlertTriangle,
  LockKeyhole,
  ChevronRight,
  BarChart3,
} from "lucide-react";

import { apiFetch } from "@/lib/api";

interface DashboardSummary {
  total_sku: number;
  total_stock: number;
  low_stock: number;
  out_of_stock: number;
}

interface DashboardResponse {
  success: boolean;
  message?: string;
  data: DashboardSummary;
}

const formatNumber = (value: number): string => {
  return new Intl.NumberFormat("id-ID").format(value);
};

export default function StatCards() {
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let isMounted = true;
    let isFirstFetch = true;

    const fetchDashboard = async () => {
      try {
        if (isFirstFetch && isMounted) {
          setLoading(true);
        }

        const response = await apiFetch("dashboard", {
          method: "GET",
          cache: "no-store",
        });

        const result: DashboardResponse = await response.json();

        if (!response.ok || !result.success || !result.data) {
          throw new Error(
            result.message || "Gagal mengambil ringkasan dashboard."
          );
        }

        if (isMounted) {
          setSummary(result.data);
          setError("");
        }
      } catch (err) {
        if (isMounted) {
          setError(
            err instanceof Error
              ? err.message
              : "Terjadi kesalahan saat mengambil data dashboard."
          );
        }
      } finally {
        if (isMounted) {
          setLoading(false);
          isFirstFetch = false;
        }
      }
    };

    // Fetch pertama saat Dashboard dibuka
    fetchDashboard();

    // Refresh otomatis setiap 15 detik
    const interval = window.setInterval(fetchDashboard, 15000);

    // Refresh saat user kembali ke tab Dashboard
    const handleFocus = () => {
      fetchDashboard();
    };

    window.addEventListener("focus", handleFocus);

    return () => {
      isMounted = false;
      window.clearInterval(interval);
      window.removeEventListener("focus", handleFocus);
    };
  }, []);

  const cards = [
    {
      title: "Total SKU",
      value: summary?.total_sku,
      description: "Jumlah seluruh produk terdaftar",
      icon: Package,
      className: "stat-green",
      href: "/sku-database",
    },
    {
      title: "Total Stok",
      value: summary?.total_stock,
      description: "Total unit persediaan barang",
      icon: Database,
      className: "stat-blue",
      href: "/analisis-stok",
    },
    {
      title: "Stok Menipis",
      value: summary?.low_stock,
      description: "Barang yang perlu diperiksa",
      icon: AlertTriangle,
      className: "stat-orange",
      href: "/analisis-stok",
    },
    {
      title: "Stok Habis",
      value: summary?.out_of_stock,
      description: "Barang yang tidak tersedia",
      icon: LockKeyhole,
      className: "stat-red",
      href: "/analisis-stok",
    },
  ];

  return (
    <>
      <div className="dashboard-stat-grid">
        {cards.map((card) => {
          const Icon = card.icon;

          return (
            <Link
              key={card.title}
              href={card.href}
              className={`dashboard-stat-card ${card.className}`}
            >
              <div className="stat-icon-box">
                <Icon size={27} />
              </div>

              <div className="stat-main">
                <span className="stat-title">{card.title}</span>

                <strong className="stat-value">
                  {loading
                    ? "..."
                    : summary
                      ? formatNumber(card.value ?? 0)
                      : "—"}
                </strong>

                <span className="stat-change">{card.description}</span>
              </div>

              <ChevronRight className="stat-arrow" size={18} />

              <div className="stat-mini-chart">
                <BarChart3 size={24} />
              </div>
            </Link>
          );
        })}
      </div>

      {error && (
        <p role="alert" className="dashboard-error-message">
          {error}
        </p>
      )}
    </>
  );
}