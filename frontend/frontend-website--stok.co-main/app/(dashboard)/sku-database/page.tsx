"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import {
  AlertCircle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Layers3,
  Pencil,
  Plus,
  Search,
  Trash2,
} from "lucide-react";

import ProfilManager from "@/components/profile/ProfilManager";
import { apiFetch } from "@/lib/api";
import UpdateStokModal from "./components/UpdateStokModal";

// ==========================================
// TYPES
// ==========================================

export type SKUData = {
  id: number;
  sku: string;
  nama: string;
  kategori: string;
  stok: number;
  lokasi: string;
  reseller_name: string | null;
  minimum_stock: number;
  unit: string | null;
  price: number;
  description: string | null;
  category_id: number | null;
};

type APIProduct = {
  id: number;
  owner_id?: number;
  category_id?: number | null;
  category_name?: string | null;
  name: string;
  reseller_name?: string | null;
  sku?: string | null;
  description?: string | null;
  stock?: number;
  minimum_stock?: number;
  unit?: string | null;
  price?: number;
  location?: string | null;
  image_key?: string | null;
};

type APIResponse = {
  success: boolean;
  message?: string;
  data?: APIProduct[];
};

type APIActionResponse = {
  success: boolean;
  message?: string;
  data?: APIProduct;
};

// ==========================================
// HELPERS
// ==========================================

const getStatus = (stok: number, minimumStock: number = 5) => {
  if (stok <= 0) {
    return {
      label: "Habis",
      className: "bg-red-50 text-red-700 border border-red-100",
    };
  }

  if (stok <= minimumStock) {
    return {
      label: "Menipis",
      className: "bg-amber-50 text-amber-700 border border-amber-100",
    };
  }

  return {
    label: "Tersedia",
    className: "bg-emerald-50 text-emerald-700 border border-emerald-100",
  };
};

// ==========================================
// MAIN PAGE
// ==========================================

export default function SKUDatabasePage() {
  const [data, setData] = useState<SKUData[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");

  const [search, setSearch] = useState("");
  const [filterKategori, setFilterKategori] = useState("Semua");
  const [filterLokasi, setFilterLokasi] = useState("Semua");
  const [filterStatus, setFilterStatus] = useState("Semua");

  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 5;

  const [editData, setEditData] = useState<SKUData | null>(null);
  const [deleteId, setDeleteId] = useState<number | null>(null);
  const [deleting, setDeleting] = useState(false);

  // ==========================================
  // FETCH PRODUCTS FROM MYSQL / BACKEND
  // ==========================================

  const fetchSKU = useCallback(async () => {
    setLoading(true);
    setLoadError("");

    try {
      const response = await apiFetch("products");
      const result: APIResponse = await response.json();

      if (!response.ok || !result.success || !Array.isArray(result.data)) {
        throw new Error(result.message || "Gagal mengambil data SKU.");
      }

      const products: SKUData[] = result.data.map((item) => ({
        id: item.id,
        sku: item.sku ?? "",
        nama: item.name,
        kategori: item.category_name ?? "",
        stok: Number(item.stock ?? 0),
        lokasi: item.location ?? "",
        reseller_name: item.reseller_name ?? null,
        minimum_stock: Number(item.minimum_stock ?? 5),
        unit: item.unit ?? "pcs",
        price: Number(item.price ?? 0),
        description: item.description ?? null,
        category_id: item.category_id ?? null,
      }));

      setData(products);
    } catch (error) {
      console.error("Fetch SKU error:", error);

      setLoadError(
        error instanceof Error
          ? error.message
          : "Terjadi kesalahan saat mengambil data produk.",
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchSKU();
  }, [fetchSKU]);

  // ==========================================
  // CATEGORY & LOCATION OPTIONS
  // ==========================================

  const kategoriList = useMemo(() => {
    return Array.from(
      new Set(data.map((item) => item.kategori).filter(Boolean)),
    );
  }, [data]);

  const lokasiList = useMemo(() => {
    return Array.from(
      new Set(data.map((item) => item.lokasi).filter(Boolean)),
    );
  }, [data]);

  // ==========================================
  // SUMMARY
  // ==========================================

  const totalSKU = data.length;
  const totalAktif = data.filter((item) => item.stok > 0).length;
  const totalHabis = data.filter((item) => item.stok <= 0).length;
  const totalKategori = kategoriList.length;

  // ==========================================
  // SEARCH & FILTER
  // ==========================================

  const filteredData = useMemo(() => {
    return data.filter((item) => {
      const keyword = search.toLowerCase().trim();

      const matchSearch =
        !keyword ||
        item.nama.toLowerCase().includes(keyword) ||
        item.sku.toLowerCase().includes(keyword) ||
        item.kategori.toLowerCase().includes(keyword) ||
        item.lokasi.toLowerCase().includes(keyword) ||
        (item.reseller_name ?? "").toLowerCase().includes(keyword);

      const matchKategori =
        filterKategori === "Semua" || item.kategori === filterKategori;

      const matchLokasi =
        filterLokasi === "Semua" || item.lokasi === filterLokasi;

      const status = getStatus(item.stok, item.minimum_stock);

      const matchStatus =
        filterStatus === "Semua" || status.label === filterStatus;

      return matchSearch && matchKategori && matchLokasi && matchStatus;
    });
  }, [data, search, filterKategori, filterLokasi, filterStatus]);

  // ==========================================
  // PAGINATION
  // ==========================================

  const totalPages = Math.max(
    1,
    Math.ceil(filteredData.length / itemsPerPage),
  );

  const safeCurrentPage = Math.min(currentPage, totalPages);

  const paginatedData = filteredData.slice(
    (safeCurrentPage - 1) * itemsPerPage,
    safeCurrentPage * itemsPerPage,
  );

  useEffect(() => {
    setCurrentPage(1);
  }, [search, filterKategori, filterLokasi, filterStatus]);

  // ==========================================
  // UPDATE PRODUCT TO BACKEND / MYSQL
  // ==========================================

  const handleSave = async (updatedItem: SKUData) => {
    try {
      const payload = {
        name: updatedItem.nama,
        reseller_name: updatedItem.reseller_name,
        sku: updatedItem.sku,
        description: updatedItem.description,
        stock: updatedItem.stok,
        minimum_stock: updatedItem.minimum_stock,
        unit: updatedItem.unit,
        price: updatedItem.price,
        location: updatedItem.lokasi,
        category: updatedItem.kategori,
      };

      const response = await apiFetch(`products/${updatedItem.id}`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      const result: APIActionResponse = await response.json();

      if (!response.ok || !result.success) {
        throw new Error(result.message || "Gagal memperbarui data SKU.");
      }

      await fetchSKU();
      setEditData(null);

      alert("Data SKU berhasil diperbarui!");
    } catch (error) {
      console.error("Update SKU error:", error);

      alert(
        error instanceof Error
          ? error.message
          : "Terjadi kesalahan saat memperbarui SKU.",
      );
    }
  };

  // ==========================================
  // DELETE PRODUCT FROM BACKEND / MYSQL
  // ==========================================

  const handleDelete = async (id: number) => {
    setDeleting(true);

    try {
      const response = await apiFetch(`products/${id}`, {
        method: "DELETE",
      });

      const result: APIActionResponse = await response.json();

      if (!response.ok || !result.success) {
        throw new Error(result.message || "Gagal menghapus data SKU.");
      }

      setData((prev) => prev.filter((item) => item.id !== id));
      setDeleteId(null);

      alert("SKU berhasil dihapus!");
    } catch (error) {
      console.error("Delete SKU error:", error);

      alert(
        error instanceof Error
          ? error.message
          : "Terjadi kesalahan saat menghapus SKU.",
      );
    } finally {
      setDeleting(false);
    }
  };

  // ==========================================
  // RESET FILTER
  // ==========================================

  const resetFilter = () => {
    setSearch("");
    setFilterKategori("Semua");
    setFilterLokasi("Semua");
    setFilterStatus("Semua");
    setCurrentPage(1);
  };

  // ==========================================
  // RENDER
  // ==========================================

  return (
    <div className="min-h-screen bg-[#f5f8f6] p-5 sm:p-6 lg:p-8">
      <div className="mx-auto w-full max-w-[1600px] space-y-7">
        {/* HEADER */}
        <div className="flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-[#20372d]">
              SKU Database
            </h1>

            <p className="mt-2 text-sm text-gray-500">
              Kelola dan pantau seluruh data SKU produk dari database.
            </p>
          </div>

          <div className="flex items-center gap-3">
            <Link
              href="/sku-database/tambah"
              className="inline-flex items-center gap-2 rounded-xl bg-[#355b49] px-5 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-[#294938] focus:outline-none focus:ring-2 focus:ring-[#a5c3ad] focus:ring-offset-2"
            >
              <Plus size={18} />
              Tambah SKU
            </Link>

            <ProfilManager />
          </div>
        </div>

        {/* SUMMARY CARDS */}
        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-4">
          {/* Total SKU */}
          <div className="rounded-2xl border border-[#e3eae5] bg-white p-6 shadow-sm transition hover:shadow-md">
            <div className="flex items-center justify-between gap-4">
              <div>
                <p className="text-sm font-medium text-gray-500">Total SKU</p>
                <h2 className="mt-3 text-2xl font-bold text-[#20372d]">
                  {loading ? "..." : totalSKU}
                </h2>
              </div>

              <div className="rounded-xl bg-[#edf4ef] p-3.5 text-[#355b49]">
                <Layers3 size={22} />
              </div>
            </div>
          </div>

          {/* Active */}
          <div className="rounded-2xl border border-[#e3eae5] bg-white p-6 shadow-sm transition hover:shadow-md">
            <div className="flex items-center justify-between gap-4">
              <div>
                <p className="text-sm font-medium text-gray-500">SKU Aktif</p>
                <h2 className="mt-3 text-2xl font-bold text-[#20372d]">
                  {loading ? "..." : totalAktif}
                </h2>
              </div>

              <div className="rounded-xl bg-emerald-50 p-3.5 text-emerald-600">
                <CheckCircle2 size={22} />
              </div>
            </div>
          </div>

          {/* Out of Stock */}
          <div className="rounded-2xl border border-[#e3eae5] bg-white p-6 shadow-sm transition hover:shadow-md">
            <div className="flex items-center justify-between gap-4">
              <div>
                <p className="text-sm font-medium text-gray-500">SKU Habis</p>
                <h2 className="mt-3 text-2xl font-bold text-[#20372d]">
                  {loading ? "..." : totalHabis}
                </h2>
              </div>

              <div className="rounded-xl bg-red-50 p-3.5 text-red-600">
                <AlertCircle size={22} />
              </div>
            </div>
          </div>

          {/* Categories */}
          <div className="rounded-2xl border border-[#e3eae5] bg-white p-6 shadow-sm transition hover:shadow-md">
            <div className="flex items-center justify-between gap-4">
              <div>
                <p className="text-sm font-medium text-gray-500">Kategori</p>
                <h2 className="mt-3 text-2xl font-bold text-[#20372d]">
                  {loading ? "..." : totalKategori}
                </h2>
              </div>

              <div className="rounded-xl bg-[#f1edfb] p-3.5 text-violet-600">
                <Layers3 size={22} />
              </div>
            </div>
          </div>
        </div>

        {/* TABLE CONTAINER */}
        <div className="overflow-hidden rounded-2xl border border-[#e3eae5] bg-white shadow-sm">
          {/* FILTER HEADER */}
          <div className="border-b border-[#e7ede9] p-6 sm:p-7">
            <div className="flex flex-col gap-5 xl:flex-row xl:items-center xl:justify-between">
              <div>
                <h2 className="text-lg font-semibold text-[#20372d]">
                  Daftar Produk
                </h2>

                <p className="mt-2 text-sm text-gray-500">
                  Data produk tersinkron dengan database MySQL.
                </p>
              </div>

              {/* SEARCH */}
              <div className="relative w-full xl:max-w-[400px]">
                <Search
                  size={18}
                  className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400"
                />

                <input
                  type="text"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  placeholder="Cari SKU, nama, kategori..."
                  className="w-full rounded-xl border border-[#dfe7e2] bg-white py-3 pl-11 pr-4 text-sm text-gray-700 outline-none transition placeholder:text-gray-400 focus:border-[#739982] focus:ring-4 focus:ring-[#edf4ef]"
                />
              </div>
            </div>

            {/* FILTERS */}
            <div className="mt-5 flex flex-wrap items-center gap-3">
              {/* Category */}
              <select
                value={filterKategori}
                onChange={(e) => setFilterKategori(e.target.value)}
                className="min-w-[175px] rounded-xl border border-[#dfe7e2] bg-white px-4 py-3 text-sm text-gray-700 outline-none transition focus:border-[#739982] focus:ring-2 focus:ring-[#edf4ef]"
              >
                <option value="Semua">Semua Kategori</option>

                {kategoriList.map((kategori) => (
                  <option key={kategori} value={kategori}>
                    {kategori}
                  </option>
                ))}
              </select>

              {/* Location */}
              <select
                value={filterLokasi}
                onChange={(e) => setFilterLokasi(e.target.value)}
                className="min-w-[155px] rounded-xl border border-[#dfe7e2] bg-white px-4 py-3 text-sm text-gray-700 outline-none transition focus:border-[#739982] focus:ring-2 focus:ring-[#edf4ef]"
              >
                <option value="Semua">Semua Lokasi</option>

                {lokasiList.map((lokasi) => (
                  <option key={lokasi} value={lokasi}>
                    {lokasi}
                  </option>
                ))}
              </select>

              {/* Status */}
              <select
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value)}
                className="min-w-[145px] rounded-xl border border-[#dfe7e2] bg-white px-4 py-3 text-sm text-gray-700 outline-none transition focus:border-[#739982] focus:ring-2 focus:ring-[#edf4ef]"
              >
                <option value="Semua">Semua Status</option>
                <option value="Tersedia">Tersedia</option>
                <option value="Menipis">Menipis</option>
                <option value="Habis">Habis</option>
              </select>

              <button
                type="button"
                onClick={resetFilter}
                className="rounded-xl px-4 py-3 text-sm font-medium text-[#355b49] transition hover:bg-[#edf4ef]"
              >
                Reset Filter
              </button>
            </div>
          </div>

          {/* ERROR STATE */}
          {loadError && (
            <div className="m-6 flex items-start gap-3 rounded-xl border border-red-200 bg-red-50 p-5 text-red-700">
              <AlertCircle size={20} className="mt-0.5 shrink-0" />

              <div className="flex-1">
                <p className="font-semibold">Gagal memuat data SKU</p>
                <p className="mt-1.5 text-sm">{loadError}</p>

                <button
                  type="button"
                  onClick={fetchSKU}
                  className="mt-4 rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-700"
                >
                  Coba Lagi
                </button>
              </div>
            </div>
          )}

                    {/* LOADING / EMPTY / TABLE */}
          {loading ? (
            <div className="flex min-h-[300px] items-center justify-center">
              <div className="text-center">
                <div className="mx-auto h-9 w-9 animate-spin rounded-full border-4 border-[#dce9e0] border-t-[#355b49]" />
                <p className="mt-4 text-sm text-gray-500">
                  Memuat data SKU...
                </p>
              </div>
            </div>
          ) : !loadError && filteredData.length === 0 ? (
            <div className="flex min-h-[300px] flex-col items-center justify-center px-6 text-center">
              <div className="rounded-full bg-[#edf4ef] p-4 text-[#779582]">
                <Layers3 size={28} />
              </div>

              <h3 className="mt-5 font-semibold text-[#20372d]">
                {data.length === 0
                  ? "Belum ada produk di database"
                  : "Produk tidak ditemukan"}
              </h3>

              <p className="mt-2 max-w-md text-sm leading-6 text-gray-500">
                {data.length === 0
                  ? "Tambahkan produk terlebih dahulu agar data SKU muncul di sini."
                  : "Coba ubah kata pencarian atau filter yang kamu gunakan."}
              </p>

              {data.length === 0 && (
                <Link
                  href="/sku-database/tambah"
                  className="mt-5 inline-flex items-center gap-2 rounded-xl bg-[#355b49] px-5 py-3 text-sm font-semibold text-white transition hover:bg-[#294938]"
                >
                  <Plus size={16} />
                  Tambah Produk
                </Link>
              )}
            </div>
          ) : !loadError ? (
            <>
              {/* TABLE */}
              <div className="overflow-x-auto">
                <table className="w-full min-w-[900px]">
                  <thead className="bg-[#f6f9f7]">
                    <tr>
                      <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        SKU
                      </th>
                      <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Nama Produk
                      </th>
                      <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Kategori
                      </th>
                      <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Stok
                      </th>
                      <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Lokasi
                      </th>
                      <th className="px-6 py-4 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Status
                      </th>
                      <th className="px-6 py-4 text-center text-xs font-semibold uppercase tracking-wider text-gray-500">
                        Aksi
                      </th>
                    </tr>
                  </thead>

                  <tbody className="divide-y divide-[#edf1ee]">
                    {paginatedData.map((item) => {
                      const status = getStatus(
                        item.stok,
                        item.minimum_stock,
                      );

                      return (
                        <tr
                          key={item.id}
                          className="transition-colors hover:bg-[#f8faf8]"
                        >
                          <td className="px-6 py-5">
                            <span className="font-mono text-sm font-medium text-[#355b49]">
                              {item.sku || "-"}
                            </span>
                          </td>

                          <td className="px-6 py-5">
                            <div className="font-medium text-gray-900">
                              {item.nama}
                            </div>

                            {item.reseller_name && (
                              <div className="mt-1.5 text-xs text-gray-500">
                                Reseller: {item.reseller_name}
                              </div>
                            )}
                          </td>

                          <td className="px-6 py-5">
                            <span className="inline-flex rounded-lg border border-[#e5ece7] bg-[#f0f5f1] px-3 py-1.5 text-xs font-medium text-[#456650]">
                              {item.kategori || "-"}
                            </span>
                          </td>

                          <td className="px-6 py-5">
                            <span className="text-sm font-semibold text-gray-900">
                              {item.stok}
                            </span>
                            <span className="ml-1.5 text-xs text-gray-500">
                              {item.unit || "pcs"}
                            </span>
                          </td>

                          <td className="px-6 py-5 text-sm text-gray-600">
                            {item.lokasi || "-"}
                          </td>

                          <td className="px-6 py-5">
                            <span
                              className={`inline-flex whitespace-nowrap rounded-full px-3 py-1.5 text-xs font-semibold ${status.className}`}
                            >
                              {status.label}
                            </span>
                          </td>

                          <td className="px-6 py-5">
                            <div className="flex items-center justify-center gap-2">
                              <button
                                type="button"
                                onClick={() => setEditData(item)}
                                title="Edit SKU"
                                className="rounded-lg p-2.5 text-[#557d62] transition hover:bg-[#edf4ef] hover:text-[#294938]"
                              >
                                <Pencil size={17} />
                              </button>

                              <button
                                type="button"
                                onClick={() => setDeleteId(item.id)}
                                title="Hapus SKU"
                                className="rounded-lg p-2.5 text-red-500 transition hover:bg-red-50 hover:text-red-700"
                              >
                                <Trash2 size={17} />
                              </button>
                            </div>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>

              {/* PAGINATION */}
              <div className="flex flex-col gap-4 border-t border-[#e7ede9] px-6 py-5 sm:flex-row sm:items-center sm:justify-between">
                <p className="text-sm text-gray-500">
                  Menampilkan{" "}
                  <span className="font-medium text-[#20372d]">
                    {filteredData.length === 0
                      ? 0
                      : (safeCurrentPage - 1) * itemsPerPage + 1}
                  </span>{" "}
                  -{" "}
                  <span className="font-medium text-[#20372d]">
                    {Math.min(
                      safeCurrentPage * itemsPerPage,
                      filteredData.length,
                    )}
                  </span>{" "}
                  dari{" "}
                  <span className="font-medium text-[#20372d]">
                    {filteredData.length}
                  </span>{" "}
                  produk
                </p>

                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() =>
                      setCurrentPage((prev) => Math.max(1, prev - 1))
                    }
                    disabled={safeCurrentPage <= 1}
                    className="rounded-xl border border-[#dfe7e2] p-2.5 text-gray-600 transition hover:bg-[#f4f7f5] disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    <ChevronLeft size={18} />
                  </button>

                  {Array.from(
                    { length: totalPages },
                    (_, index) => index + 1,
                  )
                    .filter(
                      (page) =>
                        page === 1 ||
                        page === totalPages ||
                        Math.abs(page - safeCurrentPage) <= 1,
                    )
                    .map((page, index, arr) => (
                      <div key={page} className="flex items-center gap-1">
                        {index > 0 && arr[index - 1] !== page - 1 && (
                          <span className="px-1 text-gray-400">...</span>
                        )}

                        <button
                          type="button"
                          onClick={() => setCurrentPage(page)}
                          className={`min-w-9 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
                            page === safeCurrentPage
                              ? "bg-[#355b49] text-white shadow-sm"
                              : "text-gray-600 hover:bg-[#edf4ef] hover:text-[#355b49]"
                          }`}
                        >
                          {page}
                        </button>
                      </div>
                    ))}

                  <button
                    type="button"
                    onClick={() =>
                      setCurrentPage((prev) =>
                        Math.min(totalPages, prev + 1),
                      )
                    }
                    disabled={safeCurrentPage >= totalPages}
                    className="rounded-xl border border-[#dfe7e2] p-2.5 text-gray-600 transition hover:bg-[#f4f7f5] disabled:cursor-not-allowed disabled:opacity-40"
                  >
                    <ChevronRight size={18} />
                  </button>
                </div>
              </div>
            </>
          ) : null}

        {/* EDIT MODAL */}
        {editData && (
          <UpdateStokModal
            mode="edit"
            initialData={editData}
            categories={kategoriList}
            onClose={() => setEditData(null)}
            onSave={handleSave}
          />
        )}

        {/* DELETE CONFIRMATION */}
        {deleteId !== null && (
          <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 p-5 backdrop-blur-sm">
            <div className="w-full max-w-md rounded-2xl border border-[#e3eae5] bg-white p-7 shadow-2xl">
              <div className="flex items-start gap-4">
                <div className="rounded-xl bg-red-50 p-3.5 text-red-600">
                  <Trash2 size={22} />
                </div>

                <div>
                  <h3 className="text-lg font-bold text-[#20372d]">
                    Hapus SKU?
                  </h3>

                  <p className="mt-2 text-sm leading-6 text-gray-500">
                    Data produk ini akan dihapus dari database. Tindakan ini
                    tidak dapat dibatalkan.
                  </p>
                </div>
              </div>

              <div className="mt-7 flex justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setDeleteId(null)}
                  disabled={deleting}
                  className="rounded-xl border border-[#dfe7e2] px-5 py-3 text-sm font-semibold text-gray-700 transition hover:bg-[#f5f8f6] disabled:opacity-50"
                >
                  Batal
                </button>

                <button
                  type="button"
                  onClick={() => handleDelete(deleteId)}
                  disabled={deleting}
                  className="inline-flex items-center gap-2 rounded-xl bg-red-600 px-5 py-3 text-sm font-semibold text-white transition hover:bg-red-700 disabled:opacity-50"
                >
                  <Trash2 size={16} />
                  {deleting ? "Menghapus..." : "Ya, Hapus"}
                </button>
              </div>
            </div>
          </div>
          )}
      </div>
      </div>
    </div>
  );
}