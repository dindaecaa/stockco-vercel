"use client";

import { useEffect, useState } from "react";
import {
  Package,
  PackageCheck,
  ClipboardCheck,
  Search,
  CalendarDays,
  Boxes,
  Hash,
  RotateCcw,
  Save,
  CircleCheck,
  ClipboardList,
} from "lucide-react";

import ProfilManager from "@/components/profile/ProfilManager";
import { apiFetch } from "@/lib/api";

// ==========================================
// TYPES
// ==========================================

interface Product {
  id: number;
  name: string;
  sku: string;
  stock: number;
  unit?: string;
  category_name?: string;
}

interface ApiResponse<T> {
  data?: T;
  products?: T;
  result?: T;
}

const tujuanOptions = [
  "Penjualan",
  "Penggunaan Internal",
  "Transfer Gudang",
  "Barang Rusak",
  "Sampel / Tester",
  "Lainnya",
];

// ==========================================
// HELPERS
// ==========================================

function getProductList(result: any): Product[] {
  if (Array.isArray(result)) return result;

  if (Array.isArray(result?.data)) {
    return result.data;
  }

  if (Array.isArray(result?.data?.products)) {
    return result.data.products;
  }

  if (Array.isArray(result?.products)) {
    return result.products;
  }

  if (Array.isArray(result?.result)) {
    return result.result;
  }

  return [];
}

function getTodayLocalDate(): string {
  const now = new Date();

  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");

  return `${year}-${month}-${day}`;
}

// ==========================================
// MAIN PAGE
// ==========================================

export default function StokKeluarPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [productId, setProductId] = useState("");
  const [tujuan, setTujuan] = useState("");
  const [tanggal, setTanggal] = useState(getTodayLocalDate());
  const [jumlah, setJumlah] = useState("");
  const [catatan, setCatatan] = useState("");

  const [loadingProducts, setLoadingProducts] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  // ==========================================
  // FETCH PRODUCTS FROM DATABASE
  // ==========================================

  useEffect(() => {
    let isMounted = true;

    async function fetchProducts() {
      try {
        setLoadingProducts(true);
        setError("");

        const response = await apiFetch("products", {
          method: "GET",
          cache: "no-store",
        });

        if (!response.ok) {
          throw new Error("Gagal mengambil data barang dari database.");
        }

        const result = await response.json();
        const productList = getProductList(result);

        if (isMounted) {
          setProducts(productList);
        }
      } catch (err) {
        console.error("Fetch products error:", err);

        if (isMounted) {
          setError(
            err instanceof Error
              ? err.message
              : "Terjadi kesalahan saat mengambil data barang."
          );
        }
      } finally {
        if (isMounted) {
          setLoadingProducts(false);
        }
      }
    }

    fetchProducts();

    return () => {
      isMounted = false;
    };
  }, []);

  // ==========================================
  // SELECTED PRODUCT
  // ==========================================

  const selectedProduct = products.find(
    (product) => String(product.id) === productId
  );

  const stokTersedia = Number(selectedProduct?.stock ?? 0);
  const jumlahKeluar = Number(jumlah) || 0;

  const sisaStok =
    selectedProduct && jumlahKeluar > 0
      ? stokTersedia - jumlahKeluar
      : stokTersedia;

  // ==========================================
  // RESET FORM
  // ==========================================

  const resetForm = () => {
    setProductId("");
    setTujuan("");
    setTanggal(getTodayLocalDate());
    setJumlah("");
    setCatatan("");
    setError("");
    setSuccess("");
  };

  // ==========================================
  // SAVE STOCK OUT
  // ==========================================

  const handleSimpan = async () => {
    setError("");
    setSuccess("");

    if (!productId || !tujuan || !tanggal || !jumlah.trim()) {
      setError("Mohon lengkapi semua informasi wajib terlebih dahulu.");
      return;
    }

    if (!Number.isInteger(Number(jumlah)) || Number(jumlah) <= 0) {
      setError("Jumlah keluar harus berupa bilangan bulat lebih dari 0.");
      return;
    }

    if (!selectedProduct) {
      setError("Barang yang dipilih tidak ditemukan.");
      return;
    }

    if (Number(jumlah) > Number(selectedProduct.stock)) {
      setError(
        `Stok tidak mencukupi. Stok tersedia hanya ${selectedProduct.stock} ${selectedProduct.unit ?? "unit"}.`
      );
      return;
    }

    try {
      setSaving(true);

      const response = await apiFetch("stock-movements", {
        method: "POST",
        body: JSON.stringify({
          product_id: Number(productId),
          type: "out",
          quantity: Number(jumlah),
          customer_name: tujuan,
          transaction_date: tanggal,
          note: catatan.trim() || undefined,
        }),
      });

      const result = await response.json().catch(() => null);

      if (!response.ok) {
        throw new Error(
          result?.message ||
            result?.error ||
            "Gagal menyimpan transaksi stok keluar."
        );
      }

      setSuccess(
        `Stok keluar berhasil dicatat! ${selectedProduct.name} sebanyak ${jumlah} ${selectedProduct.unit ?? "unit"}.`
      );

      // Perbarui stok lokal setelah transaksi berhasil
      setProducts((prev) =>
        prev.map((product) =>
          product.id === Number(productId)
            ? {
                ...product,
                stock: Number(product.stock) - Number(jumlah),
              }
            : product
        )
      );

      setProductId("");
      setTujuan("");
      setTanggal(getTodayLocalDate());
      setJumlah("");
      setCatatan("");
    } catch (err) {
      console.error("Save stock out error:", err);

      setError(
        err instanceof Error
          ? err.message
          : "Terjadi kesalahan saat menyimpan stok keluar."
      );
    } finally {
      setSaving(false);
    }
  };

  // ==========================================
  // INPUT STYLES
  // ==========================================

  const inputClass =
    "w-full min-w-0 rounded-lg border border-[#d8e3d7] bg-white py-3 pl-11 pr-3 text-sm text-[#35483a] outline-none transition placeholder:text-[#9aa69c] focus:border-[#58765b] focus:ring-2 focus:ring-[#58765b]/10";

  const selectClass =
    "w-full min-w-0 appearance-none rounded-lg border border-[#d8e3d7] bg-white py-3 pl-11 pr-10 text-sm text-[#35483a] outline-none transition focus:border-[#58765b] focus:ring-2 focus:ring-[#58765b]/10 disabled:cursor-not-allowed disabled:bg-[#f4f7f4] disabled:text-[#9aa69c]";

  const iconClass =
    "pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[#89968b]";

  const selectArrowClass =
    "pointer-events-none absolute right-3.5 top-1/2 -translate-y-1/2 text-[#89968b]";

  // ==========================================
  // RENDER
  // ==========================================

  return (
    <div className="flex min-h-screen bg-[#f4f7f4]">
      <main className="min-w-0 flex-1 px-4 py-5 sm:px-6 lg:px-8">

        {/* HEADER */}
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="mb-2 flex items-center gap-2 text-xs text-[#718074]">
              <span>Dashboard</span>
              <span>/</span>
              <span className="text-[#58765b]">
                Stok Keluar
              </span>
            </div>

            <h1 className="text-2xl font-semibold tracking-tight text-[#263b2b] sm:text-3xl">
              Stok Keluar
            </h1>

            <p className="mt-2 text-sm leading-6 text-[#718074]">
              Catat pengeluaran barang dan perbarui informasi inventori.
            </p>
          </div>

          <div className="flex items-center sm:justify-end">
            <ProfilManager />
          </div>
        </div>

        {/* CARD RINGKASAN */}
        <div className="sm-summary-grid">
          <div className="sm-summary-card">
            <div className="sm-summary-icon">
              <PackageCheck />
            </div>

            <div className="sm-summary-text">
              <p className="sm-summary-label">
                Pencatatan Pengeluaran
              </p>
              <p className="sm-summary-value">
                Form Stok Keluar
              </p>
            </div>
          </div>

          <div className="sm-summary-card">
            <div className="sm-summary-icon">
              <ClipboardCheck />
            </div>

            <div className="sm-summary-text">
              <p className="sm-summary-label">
                Data Wajib
              </p>
              <p className="sm-summary-value">
                5 informasi harus diisi
              </p>
            </div>
          </div>
        </div>

        {/* FORM DAN INFORMASI TAMBAHAN */}
        <div className="grid grid-cols-1 items-start gap-5 xl:grid-cols-[minmax(0,1.8fr)_minmax(280px,0.9fr)]">

          {/* FORM PENGELUARAN */}
          <section className="min-w-0 overflow-hidden rounded-xl border border-[#dfe8de] bg-white shadow-sm">

            {/* FORM HEADER */}
            <div className="flex items-center gap-3 border-b border-[#e6ece5] px-5 py-5 sm:px-7">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[#edf4ec] text-[#58765b]">
                <Package size={21} strokeWidth={1.6} />
              </div>

              <div>
                <h2 className="text-base font-semibold text-[#263b2b]">
                  Form Pengeluaran Barang
                </h2>

                <p className="mt-1 text-xs leading-5 text-[#718074]">
                  Lengkapi informasi barang yang dikeluarkan dari gudang.
                </p>
              </div>
            </div>

            <div className="space-y-5 p-5 sm:p-7">

              {/* PILIH BARANG - DROPDOWN */}
              <div>
                <label
                  htmlFor="barang"
                  className="mb-2 block text-sm font-medium text-[#35483a]"
                >
                  Pilih Barang <span className="text-red-500">*</span>
                </label>

                <div className="relative">
                  <Search size={18} className={iconClass} />

                  <select
                    id="barang"
                    value={productId}
                    onChange={(e) => {
                      setProductId(e.target.value);
                      setJumlah("");
                      setError("");
                      setSuccess("");
                    }}
                    disabled={loadingProducts || products.length === 0}
                    className={selectClass}
                  >
                    <option value="">
                      {loadingProducts
                        ? "Memuat data barang..."
                        : products.length === 0
                          ? "Belum ada barang di database"
                          : "Pilih barang dari database"}
                    </option>

                    {products.map((product) => (
                      <option
                        key={product.id}
                        value={String(product.id)}
                      >
                        {product.sku} — {product.name} (Stok: {product.stock})
                      </option>
                    ))}
                  </select>

                  <span className={selectArrowClass}>
                    ▾
                  </span>
                </div>
              </div>

              {/* STOK TERSEDIA */}
              {selectedProduct && (
                <div className="rounded-lg border border-[#dfe8de] bg-[#f6f9f5] p-4">
                  <div className="flex items-center gap-3">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[#edf4ec] text-[#58765b]">
                      <Package size={20} />
                    </div>

                    <div className="min-w-0 flex-1">
                      <p className="text-xs text-[#718074]">
                        Barang yang dipilih
                      </p>
                      <p className="truncate text-sm font-semibold text-[#35483a]">
                        {selectedProduct.name}
                      </p>
                    </div>
                  </div>

                  <div className="mt-4 grid grid-cols-2 gap-3">
                    <div className="rounded-lg bg-white p-3">
                      <p className="text-xs text-[#718074]">
                        SKU
                      </p>
                      <p className="mt-1 break-all text-sm font-semibold text-[#35483a]">
                        {selectedProduct.sku || "-"}
                      </p>
                    </div>

                    <div className="rounded-lg bg-white p-3">
                      <p className="text-xs text-[#718074]">
                        Stok Tersedia
                      </p>
                      <p className="mt-1 text-sm font-semibold text-[#58765b]">
                        {selectedProduct.stock}{" "}
                        {selectedProduct.unit || "unit"}
                      </p>
                    </div>
                  </div>
                </div>
              )}

              {/* TUJUAN DAN TANGGAL */}
              <div className="grid grid-cols-1 gap-5 sm:grid-cols-2">

                {/* TUJUAN - DROPDOWN */}
                <div className="min-w-0">
                  <label
                    htmlFor="tujuan"
                    className="mb-2 block text-sm font-medium text-[#35483a]"
                  >
                    Tujuan Pengeluaran{" "}
                    <span className="text-red-500">*</span>
                  </label>

                  <div className="relative">
                    <ClipboardList size={18} className={iconClass} />

                    <select
                      id="tujuan"
                      value={tujuan}
                      onChange={(e) => {
                        setTujuan(e.target.value);
                        setError("");
                      }}
                      className={selectClass}
                    >
                      <option value="">
                        Pilih tujuan pengeluaran
                      </option>

                      {tujuanOptions.map((option) => (
                        <option key={option} value={option}>
                          {option}
                        </option>
                      ))}
                    </select>

                    <span className={selectArrowClass}>
                      ▾
                    </span>
                  </div>
                </div>

                {/* TANGGAL */}
                <div className="min-w-0">
                  <label
                    htmlFor="tanggal"
                    className="mb-2 block text-sm font-medium text-[#35483a]"
                  >
                    Tanggal Barang Keluar{" "}
                    <span className="text-red-500">*</span>
                  </label>

                  <div className="relative">
                    <CalendarDays size={18} className={iconClass} />

                    <input
                      id="tanggal"
                      type="date"
                      value={tanggal}
                      onChange={(e) => setTanggal(e.target.value)}
                      max={getTodayLocalDate()}
                      className={inputClass}
                    />
                  </div>
                </div>
              </div>

              {/* JUMLAH DAN SKU */}
              <div className="grid grid-cols-1 gap-5 sm:grid-cols-2">

                {/* JUMLAH */}
                <div className="min-w-0">
                  <label
                    htmlFor="jumlah"
                    className="mb-2 block text-sm font-medium text-[#35483a]"
                  >
                    Jumlah Keluar{" "}
                    <span className="text-red-500">*</span>
                  </label>

                  <div className="relative">
                    <Boxes size={18} className={iconClass} />

                    <input
                      id="jumlah"
                      type="number"
                      min="1"
                      max={selectedProduct?.stock ?? undefined}
                      step="1"
                      value={jumlah}
                      onChange={(e) => {
                        setJumlah(e.target.value);
                        setError("");
                        setSuccess("");
                      }}
                      disabled={!selectedProduct}
                      placeholder="Contoh: 5"
                      className={inputClass}
                    />
                  </div>

                  {selectedProduct && (
                    <p
                      className={`mt-2 text-xs ${
                        jumlahKeluar > stokTersedia
                          ? "text-red-500"
                          : "text-[#89968b]"
                      }`}
                    >
                      Maksimal {stokTersedia}{" "}
                      {selectedProduct.unit || "unit"}
                    </p>
                  )}
                </div>

                {/* SKU OTOMATIS */}
                <div className="min-w-0">
                  <label
                    htmlFor="sku"
                    className="mb-2 block text-sm font-medium text-[#35483a]"
                  >
                    SKU
                  </label>

                  <div className="relative">
                    <Hash size={18} className={iconClass} />

                    <input
                      id="sku"
                      type="text"
                      value={selectedProduct?.sku ?? ""}
                      readOnly
                      placeholder="SKU otomatis dari barang"
                      className={`${inputClass} cursor-not-allowed bg-[#f4f7f4]`}
                    />
                  </div>
                </div>
              </div>

              {/* PREVIEW SISA STOK */}
              {selectedProduct && jumlah !== "" && jumlahKeluar > 0 && (
                <div
                  className={`rounded-lg border p-3 ${
                    jumlahKeluar > stokTersedia
                      ? "border-red-200 bg-red-50"
                      : "border-[#dfe8de] bg-[#f6f9f5]"
                  }`}
                >
                  <div className="flex items-center justify-between gap-3">
                    <span className="text-sm text-[#718074]">
                      Perkiraan sisa stok setelah transaksi
                    </span>

                    <span
                      className={`text-sm font-semibold ${
                        jumlahKeluar > stokTersedia
                          ? "text-red-600"
                          : "text-[#58765b]"
                      }`}
                    >
                      {sisaStok < 0 ? 0 : sisaStok}{" "}
                      {selectedProduct.unit || "unit"}
                    </span>
                  </div>

                  {jumlahKeluar > stokTersedia && (
                    <p className="mt-2 text-xs text-red-500">
                      Jumlah pengeluaran melebihi stok tersedia.
                    </p>
                  )}
                </div>
              )}

              {/* CATATAN */}
              <div>
                <label
                  htmlFor="catatan"
                  className="mb-2 block text-sm font-medium text-[#35483a]"
                >
                  Catatan{" "}
                  <span className="font-normal text-[#89968b]">
                    (Opsional)
                  </span>
                </label>

                <textarea
                  id="catatan"
                  rows={3}
                  value={catatan}
                  onChange={(e) => setCatatan(e.target.value)}
                  placeholder="Tambahkan catatan jika diperlukan..."
                  className="w-full resize-y rounded-lg border border-[#d8e3d7] bg-white px-4 py-3 text-sm leading-6 text-[#35483a] outline-none transition placeholder:text-[#9aa69c] focus:border-[#58765b] focus:ring-2 focus:ring-[#58765b]/10"
                />
              </div>

              {/* ERROR MESSAGE */}
              {error && (
                <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-600">
                  {error}
                </div>
              )}

              {/* SUCCESS MESSAGE */}
              {success && (
                <div className="rounded-lg border border-[#d5e7d4] bg-[#f0f7ef] px-4 py-3 text-sm text-[#58765b]">
                  <div className="flex items-start gap-2">
                    <CircleCheck size={18} className="mt-0.5 shrink-0" />
                    <span>{success}</span>
                  </div>
                </div>
              )}

              {/* TOMBOL */}
              <div className="flex flex-col-reverse gap-3 border-t border-[#e6ece5] pt-5 sm:flex-row sm:justify-end">

                <button
                  type="button"
                  onClick={resetForm}
                  disabled={saving}
                  className="inline-flex items-center justify-center gap-2 rounded-lg border border-[#d8e3d7] bg-white px-5 py-3 text-sm font-medium text-[#526356] transition hover:bg-[#f4f7f2] disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <RotateCcw size={16} />
                  Batal
                </button>

                <button
                  type="button"
                  onClick={handleSimpan}
                  disabled={
                    saving ||
                    loadingProducts ||
                    !selectedProduct ||
                    jumlahKeluar <= 0 ||
                    jumlahKeluar > stokTersedia
                  }
                  className="inline-flex items-center justify-center gap-2 rounded-lg bg-[#58765b] px-5 py-3 text-sm font-medium text-white transition hover:bg-[#48664b] focus:outline-none focus:ring-2 focus:ring-[#58765b]/30 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <Save size={17} />
                  {saving ? "Menyimpan..." : "Simpan Pengeluaran"}
                </button>
              </div>
            </div>
          </section>

          {/* INFORMASI TAMBAHAN */}
          <aside className="sm-info-card">

            <div className="sm-info-header">
              <h2 className="sm-info-title">
                Informasi Tambahan
              </h2>

              <p className="sm-info-description">
                Panduan singkat pencatatan barang keluar.
              </p>
            </div>

            <div className="sm-info-content">

              <div className="sm-info-visual">
                <Boxes size={32} strokeWidth={1.5} />
              </div>

              <section className="sm-info-section">
                <h3>Pastikan Data Sudah Benar</h3>

                <p>
                  Periksa informasi barang sebelum menyimpan pencatatan
                  stok keluar agar data inventori tetap teratur.
                </p>
              </section>

              <section className="sm-info-section">
                <h3>Checklist Pengeluaran</h3>

                <ul className="sm-checklist">
                  <li>
                    <CircleCheck />
                    <span>Barang yang dipilih sudah sesuai</span>
                  </li>

                  <li>
                    <CircleCheck />
                    <span>Tujuan pengeluaran sudah dicatat</span>
                  </li>

                  <li>
                    <CircleCheck />
                    <span>Jumlah barang sudah benar</span>
                  </li>

                  <li>
                    <CircleCheck />
                    <span>SKU sesuai dengan barang</span>
                  </li>
                </ul>
              </section>

              <div className="sm-info-tip">
                <ClipboardList size={19} strokeWidth={1.6} />

                <div>
                  <h3 className="text-sm font-semibold text-[#35483a]">
                    Tips Pencatatan
                  </h3>

                  <p>
                    Catat tujuan pengeluaran dengan jelas agar pergerakan
                    stok mudah ditelusuri.
                  </p>
                </div>
              </div>

            </div>
          </aside>
        </div>
      </main>
    </div>
  );
}