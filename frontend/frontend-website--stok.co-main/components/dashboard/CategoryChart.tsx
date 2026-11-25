"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";

import { apiFetch } from "@/lib/api";

// ==========================================
// TYPES
// ==========================================

interface CategoryApiItem {
  category_id: number | null;
  category_name: string;
  total_products: number;
  percentage: number;
}

interface CategoryApiResponse {
  success: boolean;
  message?: string;
  data: {
    total_products: number;
    data: CategoryApiItem[];
  };
}

interface Category {
  id: number | null;
  name: string;
  total: number;
  value: number;
  dotClass: string;
  color: string;
}

// ==========================================
// CATEGORY COLORS
// ==========================================

const categoryColors = [
  { dotClass: "dot-green", color: "#22c55e" },
  { dotClass: "dot-blue", color: "#3b82f6" },
  { dotClass: "dot-yellow", color: "#eab308" },
  { dotClass: "dot-red", color: "#ef4444" },
  { dotClass: "dot-purple", color: "#a855f7" },
  { dotClass: "dot-orange", color: "#f97316" },
  { dotClass: "dot-cyan", color: "#06b6d4" },
  { dotClass: "dot-pink", color: "#ec4899" },
];

// ==========================================
// COMPONENT
// ==========================================

export default function CategoryChart() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [totalProducts, setTotalProducts] = useState(0);
  const [selectedCategory, setSelectedCategory] =
    useState<Category | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  // ==========================================
  // FETCH CATEGORY DATA
  // ==========================================

  const fetchCategories = useCallback(async () => {
    try {
      setError("");

      const response = await apiFetch("dashboard/categories", {
        method: "GET",
        cache: "no-store",
      });

      const result: CategoryApiResponse = await response.json();

      if (!response.ok || !result.success || !result.data) {
        throw new Error(
          result.message || "Gagal mengambil data kategori."
        );
      }

      // Backend mengembalikan:
      // data: {
      //   total_products: number,
      //   data: CategoryApiItem[]
      // }

      const categoryData: CategoryApiItem[] =
        Array.isArray(result.data.data)
          ? result.data.data
          : [];

      const mappedCategories: Category[] =
        categoryData.map(
          (category: CategoryApiItem, index: number) => {
            const color =
              categoryColors[
                index % categoryColors.length
              ];

            return {
              id: category.category_id,
              name: category.category_name,
              total: Number(category.total_products) || 0,
              value: Number(category.percentage) || 0,
              dotClass: color.dotClass,
              color: color.color,
            };
          }
        );

      setCategories(mappedCategories);
      setTotalProducts(
        Number(result.data.total_products) || 0
      );
      setSelectedCategory(null);
    } catch (err: unknown) {
      setError(
        err instanceof Error
          ? err.message
          : "Terjadi kesalahan saat mengambil data kategori."
      );
    } finally {
      setLoading(false);
    }
  }, []);

  // ==========================================
  // INITIAL FETCH & AUTO REFRESH
  // ==========================================

  useEffect(() => {
    fetchCategories();

    // Refresh ketika tab/browser kembali aktif
    const handleVisibilityChange = () => {
      if (document.visibilityState === "visible") {
        fetchCategories();
      }
    };

    // Refresh ketika window kembali difokuskan
    const handleFocus = () => {
      fetchCategories();
    };

    document.addEventListener(
      "visibilitychange",
      handleVisibilityChange
    );

    window.addEventListener("focus", handleFocus);

    return () => {
      document.removeEventListener(
        "visibilitychange",
        handleVisibilityChange
      );

      window.removeEventListener("focus", handleFocus);
    };
  }, [fetchCategories]);

  // ==========================================
  // DONUT CHART
  // ==========================================

  const donutBackground = useMemo(() => {
    if (categories.length === 0 || totalProducts === 0) {
      return "conic-gradient(#e5e7eb 0% 100%)";
    }

    let currentPercentage = 0;

    const segments = categories
      .filter((category) => category.value > 0)
      .map((category) => {
        const start = currentPercentage;

        currentPercentage += category.value;

        return `${category.color} ${start}% ${currentPercentage}%`;
      });

    return segments.length > 0
      ? `conic-gradient(${segments.join(", ")})`
      : "conic-gradient(#e5e7eb 0% 100%)";
  }, [categories, totalProducts]);

  // ==========================================
  // RENDER
  // ==========================================

  return (
    <div className="category-dashboard-card">
      {/* HEADER */}
      <div className="category-dashboard-header">
        <div className="category-title">
          <div className="category-title-icon">📋</div>
          <h2>Kategori Terbanyak</h2>
        </div>

        <Link
          href="/kategori-terbanyak"
          className="category-see-all"
        >
          Lihat Semua →
        </Link>
      </div>

      <div className="category-dashboard-content">
        {/* DONUT */}
        <div className="donut-wrapper">
          <div
            className={`donut-chart ${
              selectedCategory ? "donut-active" : ""
            }`}
            style={{ background: donutBackground }}
          >
            <div className="donut-center">
              <strong>
                {loading
                  ? "..."
                  : selectedCategory
                    ? `${selectedCategory.value}%`
                    : totalProducts.toLocaleString("id-ID")}
              </strong>

              <span>
                {selectedCategory
                  ? selectedCategory.name
                  : "Total SKU"}
              </span>
            </div>
          </div>
        </div>

        {/* CATEGORY LEGEND */}
        <div className="category-legend">
          {loading && (
            <p className="category-loading">
              Memuat data kategori...
            </p>
          )}

          {!loading && error && (
            <p className="category-error" role="alert">
              {error}
            </p>
          )}

          {!loading &&
            !error &&
            categories.length === 0 && (
              <p className="category-empty">
                Belum ada data kategori produk.
              </p>
            )}

          {!loading &&
            !error &&
            categories.map((category: Category) => (
              <div
                key={
                  category.id !== null
                    ? category.id
                    : "uncategorized"
                }
                className={`category-row ${
                  selectedCategory?.id === category.id &&
                  selectedCategory?.name === category.name
                    ? "category-row-active"
                    : ""
                }`}
                onMouseEnter={() =>
                  setSelectedCategory(category)
                }
                onMouseLeave={() =>
                  setSelectedCategory(null)
                }
              >
                <span>
                  <i
                    className={`category-dot ${category.dotClass}`}
                    style={{
                      backgroundColor: category.color,
                    }}
                  />

                  {category.name}
                </span>

                <strong>
                  {category.value.toLocaleString("id-ID", {
                    maximumFractionDigits: 2,
                  })}
                  %
                </strong>
              </div>
            ))}
        </div>
      </div>
    </div>
  );
}