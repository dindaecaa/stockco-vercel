
"use client";

import { useState } from "react";
import Link from "next/link";
import {
  Laptop,
  Package,
  Armchair,
  Warehouse,
  Boxes,
  CheckCircle2,
  PackagePlus,
} from "lucide-react";

import ProfilManager from "@/components/profile/ProfilManager";
import { apiFetch } from "@/lib/api";

const kategoriBarang = [
  { nama: "Elektronik", Icon: Laptop },
  { nama: "Aksesoris", Icon: Package },
  { nama: "Furniture", Icon: Armchair },
  { nama: "Peralatan Gudang", Icon: Warehouse },
  { nama: "Lainnya", Icon: Boxes },
];

type SKUPreview = {
  id: number;
  sku: string;
  name: string;
  category: string;
  stock: number;
  location: string;
};

type ProductResponse = {
  id: number;
  sku?: string;
  name: string;
  category?: string;
  category_name?: string;
  stock: number;
  location?: string;
};

type APIResponse = {
  success: boolean;
  message?: string;
  data?: ProductResponse;
};

export default function TambahSKUPage() {
  const [kategori, setKategori] = useState("");
  const [isPending, setIsPending] = useState(false);
  const [message, setMessage] = useState("");
  const [success, setSuccess] = useState(false);
  const [savedSKU, setSavedSKU] = useState<SKUPreview | null>(null);

  async function handleSubmit(
    event: React.FormEvent<HTMLFormElement>
  ) {
    event.preventDefault();

    if (isPending) return;

    const form = event.currentTarget;
    const formData = new FormData(form);

    const nama = String(formData.get("nama") ?? "").trim();
    const kategoriForm = String(
      formData.get("kategori") ?? ""
    ).trim();
    const rawStok = String(formData.get("stok") ?? "");
    const lokasi = String(
      formData.get("lokasi") ?? ""
    ).trim();
    const deskripsi = String(
      formData.get("deskripsi") ?? ""
    ).trim();

    const stok = Number(rawStok);

    if (!nama || !kategoriForm || !rawStok || !lokasi) {
      setSuccess(false);
      setMessage("Lengkapi semua data wajib terlebih dahulu.");
      return;
    }

    if (!Number.isInteger(stok) || stok < 0) {
      setSuccess(false);
      setMessage("Stok harus berupa bilangan bulat dan tidak boleh negatif.");
      return;
    }

    setIsPending(true);
    setMessage("");
    setSavedSKU(null);

    try {
      const response = await apiFetch("products", {
        method: "POST",
        body: JSON.stringify({
          name: nama,
          category: kategoriForm,
          stock: stok,
          location: lokasi,
          description: deskripsi,
          unit: "pcs",
          price: 0,
        }),
      });

      const result: APIResponse = await response.json();

      if (!response.ok || !result.success || !result.data) {
        throw new Error(
          result.message || "Gagal menyimpan SKU."
        );
      }

      const product = result.data;

      setSavedSKU({
        id: Number(product.id),
        sku: product.sku ?? `SKU-${product.id}`,
        name: product.name ?? nama,
        category:
          product.category_name ??
          product.category ??
          kategoriForm,
        stock: Number(product.stock ?? stok),
        location: product.location ?? lokasi,
      });

      setSuccess(true);
      setMessage("SKU berhasil ditambahkan.");

      form.reset();
      setKategori("");
    } catch (error) {
      console.error("Gagal menyimpan SKU:", error);

      setSuccess(false);
      setMessage(
        error instanceof Error
          ? error.message
          : "Terjadi kesalahan saat menyimpan SKU."
      );
    } finally {
      setIsPending(false);
    }
  }

  return (
    <div className="sku-page">
      <main className="sku-main">
        <header className="sku-topbar">
          <div>
            <p>Dashboard / SKU Database / Tambah SKU</p>
            <h1>Tambah SKU</h1>
          </div>

          <ProfilManager />
        </header>

        <section className="sku-content">
          <div className="sku-page-heading">
            <div>
              <h2>Tambah SKU</h2>
              <p>Tambahkan data barang baru ke sistem.</p>
            </div>
          </div>

          <div className="sku-form-layout">
            <form
              className="sku-form-card"
              onSubmit={handleSubmit}
            >
              <div className="sku-form-group">
                <label htmlFor="sku-nama">
                  Nama Barang
                </label>

                <input
                  id="sku-nama"
                  name="nama"
                  placeholder="Masukkan nama barang"
                  maxLength={100}
                  required
                  disabled={isPending}
                />
              </div>

              <div className="sku-form-group">
                <label htmlFor="sku-kategori">
                  Kategori
                </label>

                <select
                  id="sku-kategori"
                  name="kategori"
                  value={kategori}
                  onChange={(e) =>
                    setKategori(e.target.value)
                  }
                  required
                  disabled={isPending}
                >
                  <option value="">Pilih kategori</option>

                  {kategoriBarang.map((item) => (
                    <option
                      key={item.nama}
                      value={item.nama}
                    >
                      {item.nama}
                    </option>
                  ))}
                </select>
              </div>

              <div className="sku-form-group">
                <label htmlFor="sku-stok">
                  Jumlah Stok
                </label>

                <input
                  id="sku-stok"
                  name="stok"
                  type="number"
                  min="0"
                  step="1"
                  placeholder="Masukkan jumlah stok"
                  required
                  disabled={isPending}
                />
              </div>

              <div className="sku-form-group">
                <label htmlFor="sku-lokasi">
                  Rak / Lokasi
                </label>

                <input
                  id="sku-lokasi"
                  name="lokasi"
                  placeholder="Contoh: A1"
                  maxLength={100}
                  required
                  disabled={isPending}
                />
              </div>

              <div className="sku-form-group">
                <label htmlFor="sku-deskripsi">
                  Deskripsi (Opsional)
                </label>

                <textarea
                  id="sku-deskripsi"
                  name="deskripsi"
                  rows={3}
                  maxLength={500}
                  placeholder="Tambahkan deskripsi barang..."
                  disabled={isPending}
                />
              </div>

              {message && (
                <p
                  role="status"
                  className={
                    success
                      ? "text-green-600"
                      : "text-red-600"
                  }
                >
                  {message}
                </p>
              )}

              {savedSKU && (
                <div
                  className="sku-optimistic-preview"
                  aria-live="polite"
                >
                  <div className="flex items-center gap-2">
                    <CheckCircle2
                      size={20}
                      className="text-green-600"
                    />

                    <strong>SKU berhasil disimpan</strong>
                  </div>

                  <p>
                    <strong>Nama:</strong> {savedSKU.name}
                  </p>

                  <p>
                    <strong>Kategori:</strong>{" "}
                    {savedSKU.category}
                  </p>

                  <p>
                    <strong>Stok:</strong> {savedSKU.stock}
                  </p>

                  <p>
                    <strong>Lokasi:</strong>{" "}
                    {savedSKU.location}
                  </p>

                  <p>
                    <strong>Kode SKU:</strong> {savedSKU.sku}
                  </p>
                </div>
              )}

              <div className="sku-form-actions">
                <Link
                  href="/sku-database"
                  className="sku-cancel-button"
                >
                  Batal
                </Link>

                <button
                  type="submit"
                  className="sku-save-button"
                  disabled={isPending}
                >
                  {isPending ? "Menyimpan..." : "Simpan"}
                </button>
              </div>
            </form>

            <aside className="sku-category-card">
              <h3>Kategori Barang</h3>

              {kategoriBarang.map(({ nama, Icon }) => (
                <button
                  type="button"
                  key={nama}
                  onClick={() => setKategori(nama)}
                  disabled={isPending}
                  className={`sku-category-item ${
                    kategori === nama ? "selected" : ""
                  }`}
                >
                  <span className="sku-category-icon">
                    <Icon size={17} />
                  </span>

                  <span>{nama}</span>
                </button>
              ))}
            </aside>
          </div>
        </section>
      </main>
    </div>
  );
}
