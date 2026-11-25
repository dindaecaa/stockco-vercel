
"use client";

import { useState, type FormEvent } from "react";

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

type EditProps = {
  mode: "edit";
  initialData: SKUData;
  categories: string[];
  onClose: () => void;
  onSave: (data: SKUData) => Promise<void> | void;
};

type AddProps = {
  mode: "add";
  initialData?: undefined;
  categories?: string[];
  onClose: () => void;
  onSave: (data: Omit<SKUData, "id">) => Promise<void> | void;
};

type UpdateStokModalProps = AddProps | EditProps;

export default function UpdateStokModal(props: UpdateStokModalProps) {
  const { mode, onClose } = props;

  const initial = mode === "edit" ? props.initialData : null;

  const [sku, setSku] = useState(initial?.sku ?? "");
  const [nama, setNama] = useState(initial?.nama ?? "");
  const [kategori, setKategori] = useState(initial?.kategori ?? "");
  const [lokasi, setLokasi] = useState(initial?.lokasi ?? "");
  const [isSaving, setIsSaving] = useState(false);

  const categories =
    props.categories ?? [];

  const handleSubmit = async (e: FormEvent<HTMLFormElement>) => {
    e.preventDefault();

    if (!sku.trim() || !nama.trim() || !kategori.trim() || !lokasi.trim()) {
      alert("Mohon lengkapi semua data SKU.");
      return;
    }

    setIsSaving(true);

    try {
      if (mode === "edit") {
        await props.onSave({
          ...props.initialData,
          sku: sku.trim(),
          nama: nama.trim(),
          kategori: kategori.trim(),
          lokasi: lokasi.trim(),
        });
      } else {
        await props.onSave({
          sku: sku.trim(),
          nama: nama.trim(),
          kategori: kategori.trim(),
          lokasi: lokasi.trim(),
          stok: 0,
          reseller_name: null,
          minimum_stock: 5,
          unit: "pcs",
          price: 0,
          description: null,
          category_id: null,
        });
      }
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30">
      <div className="w-97.5 max-w-[calc(100vw-32px)] bg-white p-5 shadow-lg">
        <h2 className="mb-6 text-lg font-bold text-[#1A1A1A]">
          {mode === "edit" ? "Edit SKU" : "Tambah SKU"}
        </h2>

        <form onSubmit={handleSubmit}>
          <div className="mb-3 flex items-center">
            <label htmlFor="sku" className="w-26.25 text-xs">
              Kode SKU
            </label>

            <input
              id="sku"
              type="text"
              maxLength={50}
              value={sku}
              onChange={(e) => setSku(e.target.value)}
              placeholder="Masukkan kode SKU"
              className="h-10 flex-1 border border-[#22C77A] px-3 text-xs outline-none"
              required
            />
          </div>

          <div className="mb-3 flex items-center">
            <label htmlFor="nama" className="w-26.25 text-xs">
              Nama Barang
            </label>

            <input
              id="nama"
              type="text"
              maxLength={150}
              value={nama}
              onChange={(e) => setNama(e.target.value)}
              placeholder="Masukkan nama barang"
              className="h-10 flex-1 border border-[#22C77A] px-3 text-xs outline-none"
              required
            />
          </div>

          <div className="mb-3 flex items-center">
            <label htmlFor="kategori" className="w-26.25 text-xs">
              Kategori
            </label>

            <select
              id="kategori"
              value={kategori}
              onChange={(e) => setKategori(e.target.value)}
              className="h-10 flex-1 border border-[#22C77A] bg-white px-3 text-xs outline-none"
              required
            >
              <option value="">Pilih Kategori</option>

              {categories.map((item) => (
                <option key={item} value={item}>
                  {item}
                </option>
              ))}
            </select>
          </div>

          {mode === "edit" && (
            <div className="mb-3 flex items-center">
              <label className="w-26.25 text-xs">
                Jumlah Stok
              </label>

              <div className="flex h-10 flex-1 items-center border border-gray-200 bg-gray-50 px-3 text-xs text-gray-600">
                {props.initialData.stok}{" "}
                {props.initialData.unit || "pcs"}
                <span className="ml-auto text-[10px]">
                  Tidak dapat diubah
                </span>
              </div>
            </div>
          )}

          <div className="mb-5 flex items-center">
            <label htmlFor="lokasi" className="w-26.25 text-xs">
              Rak / Lokasi
            </label>

            <input
              id="lokasi"
              type="text"
              maxLength={100}
              value={lokasi}
              onChange={(e) => setLokasi(e.target.value)}
              placeholder="Contoh: A1"
              className="h-10 flex-1 border border-[#22C77A] px-3 text-xs outline-none"
              required
            />
          </div>

          <div className="flex justify-end gap-5">
            <button
              type="button"
              onClick={onClose}
              disabled={isSaving}
              className="h-8 w-16.25 rounded-md border border-[#22C77A] text-xs disabled:opacity-50"
            >
              Batal
            </button>

            <button
              type="submit"
              disabled={isSaving}
              className="h-8 w-16.25 rounded-md bg-[#587653] text-xs text-white disabled:opacity-50"
            >
              {isSaving
                ? "..."
                : mode === "edit"
                  ? "Update"
                  : "Simpan"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
