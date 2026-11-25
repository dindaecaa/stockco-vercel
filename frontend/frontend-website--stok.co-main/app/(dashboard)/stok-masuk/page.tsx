
"use client";

import { useEffect, useState } from "react";
import {
  Package,
  PackageCheck,
  ClipboardCheck,
  Truck,
  CalendarDays,
  Boxes,
  RotateCcw,
  Save,
  CircleCheck,
  ClipboardList,
} from "lucide-react";

import ProfilManager from "@/components/profile/ProfilManager";
import { apiFetch } from "@/lib/api";

interface Product {
  id: number;
  name: string | null;
  reseller_name: string | null;
  sku: string | null;
}

interface ProductsResponse {
  success: boolean;
  data: Product[];
  message?: string;
}

interface StockMovementResponse {
  success: boolean;
  message?: string;
  data?: {
    id: number;
    product_id: number;
    type: "in" | "out";
    quantity: number;
    stock_before: number;
    stock_after: number;
  };
}

export default function StokMasukPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [selectedProductId, setSelectedProductId] = useState("");
  const [pemasok, setPemasok] = useState("");
  const [tanggal, setTanggal] = useState("");
  const [jumlah, setJumlah] = useState("");
  const [catatan, setCatatan] = useState("");

  const [isLoadingProducts, setIsLoadingProducts] = useState(true);
  const [productError, setProductError] = useState("");
  const [isSaving, setIsSaving] = useState(false);

  const selectedProduct = products.find(
    (product) => String(product.id) === selectedProductId
  );

  // TANGGAL LOKAL HARI INI
  const getTanggalHariIni = () => {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, "0");
    const day = String(now.getDate()).padStart(2, "0");

    return `${year}-${month}-${day}`;
  };

  // AMBIL DATA PRODUK DARI API
  const loadProducts = async () => {
    setIsLoadingProducts(true);
    setProductError("");

    try {
      const response = await apiFetch("products", {
        method: "GET",
        cache: "no-store",
      });

      const result = (await response.json()) as ProductsResponse;

      if (
        !response.ok ||
        !result.success ||
        !Array.isArray(result.data)
      ) {
        throw new Error(
          result.message ?? "Gagal mengambil data SKU Database."
        );
      }

      setProducts(result.data);
    } catch (error) {
      console.error("Gagal memuat data produk:", error);

      setProductError(
        error instanceof Error
          ? error.message
          : "Gagal memuat daftar barang."
      );
    } finally {
      setIsLoadingProducts(false);
    }
  };

  useEffect(() => {
    loadProducts();
  }, []);

  // OTOMATIS ISI PEMASOK, TANGGAL, DAN JUMLAH
  useEffect(() => {
    if (!selectedProduct) {
      setPemasok("");
      setTanggal("");
      setJumlah("");
      return;
    }

    setPemasok(selectedProduct.reseller_name ?? "");
    setTanggal(getTanggalHariIni());
    setJumlah("1");
  }, [selectedProduct]);

  // SIMPAN STOK MASUK KE DATABASE
  const handleSimpan = async () => {
    if (
      !selectedProductId ||
      !selectedProduct ||
      !pemasok.trim() ||
      !tanggal ||
      !jumlah.trim()
    ) {
      alert(
        "Mohon pilih barang dan pastikan informasi penerimaan sudah terisi."
      );
      return;
    }

    if (
      !Number.isInteger(Number(jumlah)) ||
      Number(jumlah) <= 0
    ) {
      alert("Jumlah barang harus berupa bilangan bulat lebih dari 0.");
      return;
    }

    if (isSaving) return;

    setIsSaving(true);

    try {
      const product = products.find(
        (item) => String(item.id) === selectedProductId
      );

      if (!product) {
        throw new Error(
          "Barang tidak ditemukan. Silakan pilih ulang barang dari SKU Database."
        );
      }

      // GABUNG CATATAN, PEMASOK, DAN TANGGAL
      const detailCatatan = [
        catatan.trim(),
        `Pemasok: ${pemasok.trim()}`,
        `Tanggal penerimaan: ${tanggal}`,
      ]
        .filter(Boolean)
        .join(" | ");

      // SIMPAN STOK MASUK + TANGGAL TRANSAKSI
      const response = await apiFetch("stock-movements", {
        method: "POST",
        body: JSON.stringify({
          product_id: product.id,
          type: "in",
          quantity: Number(jumlah),
          transaction_date: tanggal,
          note: detailCatatan,
        }),
      });

      const result =
        (await response.json()) as StockMovementResponse;

      if (!response.ok || !result.success) {
        throw new Error(
          result.message ?? "Gagal menyimpan stok masuk."
        );
      }

      alert(
        `Data stok masuk berhasil dicatat!\n\nBarang: ${product.name ?? "-"}\nJumlah masuk: ${jumlah}\nSKU: ${product.sku ?? "-"}\nPemasok: ${pemasok}\nTanggal: ${tanggal}`
      );

      handleBatal();
      await loadProducts();
    } catch (error) {
      console.error("Gagal menyimpan stok masuk:", error);

      alert(
        error instanceof Error
          ? error.message
          : "Terjadi kesalahan saat menyimpan stok masuk."
      );
    } finally {
      setIsSaving(false);
    }
  };

  // RESET FORM
  const handleBatal = () => {
    setSelectedProductId("");
    setPemasok("");
    setTanggal("");
    setJumlah("");
    setCatatan("");
  };

  const inputClass =
    "w-full min-w-0 rounded-lg border border-[#d8e3d7] bg-white py-3 pl-11 pr-3 text-sm text-[#35483a] outline-none transition placeholder:text-[#9aa69c] focus:border-[#58765b] focus:ring-2 focus:ring-[#58765b]/10";

  const iconClass =
    "pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[#89968b]";

  return (
    <div className="flex min-h-screen bg-[#f4f7f4]">
      <main className="min-w-0 flex-1 px-4 py-5 sm:px-6 lg:px-8">
        {/* HEADER */}
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <div className="mb-2 flex items-center gap-2 text-xs text-[#718074]">
              <span>Dashboard</span>
              <span>/</span>
              <span className="text-[#58765b]">Stok Masuk</span>
            </div>

            <h1 className="text-2xl font-semibold tracking-tight text-[#263b2b] sm:text-3xl">
              Stok Masuk
            </h1>

            <p className="mt-2 text-sm leading-6 text-[#718074]">
              Catat penerimaan barang dan perbarui informasi inventori.
            </p>
          </div>

          <div className="flex items-center sm:justify-end">
            <ProfilManager />
          </div>
        </div>

        {/* RINGKASAN */}
        <div className="sm-summary-grid">
          <div className="sm-summary-card">
            <div className="sm-summary-icon">
              <PackageCheck />
            </div>

            <div className="sm-summary-text">
              <p className="sm-summary-label">Pencatatan Penerimaan</p>
              <p className="sm-summary-value">Form Stok Masuk</p>
            </div>
          </div>

          <div className="sm-summary-card">
            <div className="sm-summary-icon">
              <ClipboardCheck />
            </div>

            <div className="sm-summary-text">
              <p className="sm-summary-label">Data Wajib</p>
              <p className="sm-summary-value">4 informasi harus diisi</p>
            </div>
          </div>
        </div>

        {/* FORM DAN INFORMASI TAMBAHAN */}
        <div className="grid grid-cols-1 items-start gap-5 xl:grid-cols-[minmax(0,1.8fr)_minmax(280px,0.9fr)]">
          {/* FORM UTAMA */}
          <section className="min-w-0 overflow-hidden rounded-xl border border-[#dfe8de] bg-white shadow-sm">
            <div className="flex items-center gap-3 border-b border-[#e6ece5] px-5 py-5 sm:px-7">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-[#edf4ec] text-[#58765b]">
                <Package size={21} strokeWidth={1.6} />
              </div>

              <div>
                <h2 className="text-base font-semibold text-[#263b2b]">
                  Form Penerimaan Barang
                </h2>

                <p className="mt-1 text-xs leading-5 text-[#718074]">
                  Pilih barang dari SKU Database dan data penerimaan akan terisi otomatis.
                </p>
              </div>
            </div>

            <div className="space-y-5 p-5 sm:p-7">
              {/* PILIH BARANG */}
              <div>
                <label
                  htmlFor="product"
                  className="mb-2 block text-sm font-medium text-[#35483a]"
                >
                  Pilih Barang <span className="text-red-500">*</span>
                </label>

                <div className="relative">
                  <Package
                    size={18}
                    strokeWidth={1.6}
                    className={iconClass}
                  />

                  <select
                    id="product"
                    value={selectedProductId}
                    onChange={(e) => setSelectedProductId(e.target.value)}
                    disabled={isLoadingProducts || products.length === 0}
                    className={`${inputClass} appearance-none disabled:cursor-not-allowed disabled:bg-[#f4f7f4]`}
                  >
                    <option value="">
                      {isLoadingProducts
                        ? "Memuat data barang..."
                        : productError
                          ? "Gagal memuat data barang"
                          : products.length === 0
                            ? "Belum ada barang di SKU Database"
                            : "Pilih barang dari SKU Database"}
                    </option>

                    {products.map((product) => (
                      <option
                        key={product.id}
                        value={String(product.id)}
                      >
                        {product.sku || "Tanpa SKU"} — {product.name || "Tanpa nama"}
                      </option>
                    ))}
                  </select>
                </div>

                {productError && (
                  <div className="mt-2 flex flex-wrap items-center justify-between gap-2 rounded-lg border border-red-200 bg-red-50 px-3 py-2">
                    <p className="text-xs text-red-600">{productError}</p>

                    <button
                      type="button"
                      onClick={loadProducts}
                      disabled={isLoadingProducts}
                      className="text-xs font-semibold text-red-700 underline disabled:opacity-50"
                    >
                      Coba Lagi
                    </button>
                  </div>
                )}

                {selectedProduct && (
                  <div className="mt-3 rounded-lg border border-[#dfe8de] bg-[#f7faf6] p-4">
                    <div className="flex items-start gap-3">
                      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[#edf4ec] text-[#58765b]">
                        <PackageCheck size={18} />
                      </div>

                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-semibold text-[#35483a]">
                          {selectedProduct.name || "Nama barang tidak tersedia"}
                        </p>

                        <p className="mt-1 text-xs text-[#718074]">
                          SKU: {selectedProduct.sku || "-"}
                        </p>

                        <p className="mt-1 text-xs text-[#58765b]">
                          Barang dipilih dari database produk.
                        </p>
                      </div>
                    </div>
                  </div>
                )}
              </div>

              {/* PEMASOK DAN TANGGAL */}
              <div className="grid grid-cols-1 gap-5 sm:grid-cols-2">
                <div className="min-w-0">
                  <label
                    htmlFor="pemasok"
                    className="mb-2 block text-sm font-medium text-[#35483a]"
                  >
                    Pemasok <span className="text-red-500">*</span>
                  </label>

                  <div className="relative">
                    <Truck
                      size={18}
                      strokeWidth={1.6}
                      className={iconClass}
                    />

                    <input
                      id="pemasok"
                      type="text"
                      value={pemasok}
                      readOnly
                      placeholder={
                        selectedProduct
                          ? "Pemasok tidak tersedia di database produk"
                          : "Pilih barang terlebih dahulu"
                      }
                      className={`${inputClass} bg-[#f4f7f4]`}
                    />
                  </div>

                  {selectedProduct && !pemasok && (
                    <p className="mt-2 text-xs text-amber-600">
                      Data reseller_name belum tersedia pada produk ini.
                    </p>
                  )}
                </div>

                <div className="min-w-0">
                  <label
                    htmlFor="tanggal"
                    className="mb-2 block text-sm font-medium text-[#35483a]"
                  >
                    Tanggal Barang Masuk <span className="text-red-500">*</span>
                  </label>

                  <div className="relative">
                    <CalendarDays
                      size={18}
                      strokeWidth={1.6}
                      className={iconClass}
                    />

                    <input
                      id="tanggal"
                      type="date"
                      value={tanggal}
                      readOnly
                      className={`${inputClass} bg-[#f4f7f4]`}
                    />
                  </div>
                </div>
              </div>

              {/* JUMLAH */}
              <div>
                <label
                  htmlFor="jumlah"
                  className="mb-2 block text-sm font-medium text-[#35483a]"
                >
                  Jumlah Masuk <span className="text-red-500">*</span>
                </label>

                <div className="relative">
                  <Boxes
                    size={18}
                    strokeWidth={1.6}
                    className={iconClass}
                  />

                  <input
                    id="jumlah"
                    type="number"
                    min="1"
                    step="1"
                    value={jumlah}
                    onChange={(e) => setJumlah(e.target.value)}
                    placeholder="Jumlah otomatis 1"
                    disabled={!selectedProduct}
                    className={`${inputClass} disabled:bg-[#f4f7f4]`}
                  />
                </div>

                {selectedProduct && (
                  <p className="mt-2 text-xs text-[#718074]">
                    Jumlah otomatis diisi 1. Kamu masih bisa mengubahnya sesuai barang yang diterima.
                  </p>
                )}
              </div>

              {/* CATATAN */}
              <div>
                <label
                  htmlFor="catatan"
                  className="mb-2 block text-sm font-medium text-[#35483a]"
                >
                  Catatan{" "}
                  <span className="font-normal text-[#89968b]">(Opsional)</span>
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

              {/* TOMBOL */}
              <div className="flex flex-col-reverse gap-3 border-t border-[#e6ece5] pt-5 sm:flex-row sm:justify-end">
                <button
                  type="button"
                  onClick={handleBatal}
                  disabled={isSaving}
                  className="inline-flex items-center justify-center gap-2 rounded-lg border border-[#d8e3d7] bg-white px-5 py-3 text-sm font-medium text-[#526356] transition hover:bg-[#f4f7f2] disabled:cursor-not-allowed disabled:opacity-50"
                >
                  <RotateCcw size={16} strokeWidth={1.6} />
                  Batal
                </button>

                <button
                  type="button"
                  onClick={handleSimpan}
                  disabled={
                    isSaving ||
                    isLoadingProducts ||
                    products.length === 0 ||
                    !selectedProduct ||
                    !pemasok
                  }
                  className="inline-flex items-center justify-center gap-2 rounded-lg bg-[#58765b] px-5 py-3 text-sm font-medium text-white transition hover:bg-[#48664b] focus:outline-none focus:ring-2 focus:ring-[#58765b]/30 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  <Save size={17} strokeWidth={1.7} />
                  {isSaving ? "Menyimpan..." : "Simpan Penerimaan"}
                </button>
              </div>
            </div>
          </section>

          {/* INFORMASI TAMBAHAN */}
          <aside className="sm-info-card">
            <div className="sm-info-header">
              <h2 className="sm-info-title">Informasi Tambahan</h2>

              <p className="sm-info-description">
                Panduan singkat pencatatan barang masuk.
              </p>
            </div>

            <div className="sm-info-content">
              <div className="sm-info-visual">
                <Boxes size={32} strokeWidth={1.5} />
              </div>

              <section className="sm-info-section">
                <h3>Pastikan Data Sudah Benar</h3>

                <p>
                  Periksa informasi barang sebelum menyimpan pencatatan stok masuk
                  agar data inventori tetap teratur.
                </p>
              </section>

              <section className="sm-info-section">
                <h3>Checklist Penerimaan</h3>

                <ul className="sm-checklist">
                  <li>
                    <CircleCheck />
                    <span>Barang dipilih dari SKU Database</span>
                  </li>

                  <li>
                    <CircleCheck />
                    <span>Pemasok terisi otomatis dari database</span>
                  </li>

                  <li>
                    <CircleCheck />
                    <span>Jumlah barang sudah benar</span>
                  </li>

                  <li>
                    <CircleCheck />
                    <span>Tanggal penerimaan otomatis</span>
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
                    Pilih barang yang sudah terdaftar di SKU Database agar transaksi
                    stok masuk tersimpan pada produk yang benar.
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
