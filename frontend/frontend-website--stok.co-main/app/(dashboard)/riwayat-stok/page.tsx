
"use client";

import { useCallback, useEffect, useState } from "react";
import {
  Search,
  Eye,
  ArrowLeftRight,
  TrendingUp,
  TrendingDown,
  RefreshCw,
} from "lucide-react";

import ProfilManager from "@/components/profile/ProfilManager";
import { apiFetch } from "@/lib/api";

type RiwayatStok = {
  id: number;
  tanggal: string;
  jenis: "Masuk" | "Keluar";
  barang: string;
  sku: string;
  jumlah: number;
  pemasokTujuan: string;
  catatan: string;
};

type APIStockMovement = {
  id: number;
  product_id: number;
  supplier_id: number | null;
  supplier_name: string | null;
  customer_name: string | null;
  product_name: string;
  product_sku: string | null;
  type: "in" | "out";
  quantity: number;
  transaction_date: string | null;
  note: string | null;
  created_at: string;
};

export default function RiwayatStokPage() {
  const [semuaData, setSemuaData] = useState<RiwayatStok[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState("");

  const [tab, setTab] = useState("Semua");
  const [halaman, setHalaman] = useState(1);
  const [cariBarang, setCariBarang] = useState("");
  const [cariPemasok, setCariPemasok] = useState("");
  const [jenisStok, setJenisStok] = useState("");
  const [periode, setPeriode] = useState("");

  const jumlahPerHalaman = 5;

  // ==========================================
  // AMBIL DATA RIWAYAT DARI BACKEND
  // ==========================================

  const fetchRiwayat = useCallback(async () => {
    try {
      setIsLoading(true);
      setLoadError("");

      const response = await apiFetch("stock-movements", {
        method: "GET",
        cache: "no-store",
      });

      const result = await response.json();

      if (!response.ok || !result.success) {
        if (response.status === 401 || response.status === 403) {
          throw new Error(
            result.message ||
              "Autentikasi belum ditemukan. Silakan login kembali."
          );
        }

        throw new Error(
          result.message || "Gagal mengambil riwayat stok."
        );
      }

      const apiData: APIStockMovement[] = Array.isArray(result.data)
        ? result.data
        : [];

      const mappedData: RiwayatStok[] = apiData.map((item) => ({
        id: item.id,
        tanggal: item.transaction_date || item.created_at,
        jenis: item.type === "in" ? "Masuk" : "Keluar",
        barang: item.product_name || "-",
        sku: item.product_sku || `SKU-${item.product_id}`,
        jumlah:
          item.type === "in"
            ? Number(item.quantity)
            : -Number(item.quantity),
        pemasokTujuan:
          item.type === "in"
            ? item.supplier_name || "—"
            : item.customer_name || "—",
        catatan: item.note || "",
      }));

      setSemuaData(mappedData);
    } catch (error) {
      console.error("Gagal mengambil riwayat stok:", error);

      setLoadError(
        error instanceof Error
          ? error.message
          : "Terjadi kesalahan saat mengambil data."
      );

      setSemuaData([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void fetchRiwayat();
  }, [fetchRiwayat]);

  // ==========================================
  // FORMAT TANGGAL
  // ==========================================

  const formatTanggal = (tanggal: string) => {
    if (!tanggal) return "—";

    const date = new Date(tanggal);

    if (Number.isNaN(date.getTime())) return tanggal;

    return date.toLocaleString("id-ID", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  // ==========================================
  // RINGKASAN TRANSAKSI
  // ==========================================

  const totalTransaksi = semuaData.length;

  const totalBarangMasuk = semuaData
    .filter((item) => item.jenis === "Masuk")
    .reduce((total, item) => total + item.jumlah, 0);

  const totalBarangKeluar = Math.abs(
    semuaData
      .filter((item) => item.jenis === "Keluar")
      .reduce((total, item) => total + item.jumlah, 0)
  );

  // ==========================================
  // FILTER DATA
  // ==========================================

  const dataFilter = semuaData.filter((item) => {
    const sesuaiTab =
      tab === "Semua" || item.jenis === tab;

    const sesuaiJenis =
      jenisStok === "" || item.jenis === jenisStok;

    const sesuaiBarang = item.barang
      .toLowerCase()
      .includes(cariBarang.toLowerCase());

    const sesuaiPemasok =
      cariPemasok.trim() === "" ||
      item.pemasokTujuan
        .toLowerCase()
        .includes(cariPemasok.toLowerCase());

    const tanggalItem = new Date(item.tanggal);
    const sekarang = new Date();

    const sesuaiPeriode = (() => {
      if (periode === "hari") {
        return (
          tanggalItem.getDate() === sekarang.getDate() &&
          tanggalItem.getMonth() === sekarang.getMonth() &&
          tanggalItem.getFullYear() === sekarang.getFullYear()
        );
      }

      if (periode === "minggu") {
        const awalMinggu = new Date(sekarang);
        const hari = (sekarang.getDay() + 6) % 7;

        awalMinggu.setDate(sekarang.getDate() - hari);
        awalMinggu.setHours(0, 0, 0, 0);

        return tanggalItem >= awalMinggu;
      }

      if (periode === "bulan") {
        return (
          tanggalItem.getMonth() === sekarang.getMonth() &&
          tanggalItem.getFullYear() === sekarang.getFullYear()
        );
      }

      return true;
    })();

    return (
      sesuaiTab &&
      sesuaiJenis &&
      sesuaiBarang &&
      sesuaiPemasok &&
      sesuaiPeriode
    );
  });

  // ==========================================
  // PAGINATION
  // ==========================================

  const totalHalaman = Math.max(
    1,
    Math.ceil(dataFilter.length / jumlahPerHalaman)
  );

  const halamanAktif = Math.min(halaman, totalHalaman);

  const dataHalaman = dataFilter.slice(
    (halamanAktif - 1) * jumlahPerHalaman,
    halamanAktif * jumlahPerHalaman
  );

  const pindahHalaman = (nomor: number) => {
    if (nomor >= 1 && nomor <= totalHalaman) {
      setHalaman(nomor);
    }
  };

  // ==========================================
  // TAMPILAN
  // ==========================================

  return (
    <div className="flex min-h-screen bg-[#f4f7f4]">
      <main className="min-w-0 flex-1 px-4 py-5 sm:px-6 lg:px-7">

        {/* HEADER */}
        <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h1 className="text-2xl font-bold leading-tight text-[#26392b]">
              Riwayat Stok
            </h1>

            <p className="mt-1 text-sm text-[#758176]">
              Lihat seluruh riwayat barang masuk dan barang keluar dari gudang.
            </p>
          </div>

          <div className="self-start">
            <ProfilManager />
          </div>
        </div>

        {/* CARD RINGKASAN */}
        <section className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">

          <div className="flex min-w-0 items-center gap-4 rounded-xl border border-[#dfe8de] bg-white p-4 shadow-sm transition-shadow hover:shadow-md sm:p-5">
            <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg bg-[#edf4ec] text-[#587653]">
              <ArrowLeftRight size={22} strokeWidth={1.8} />
            </div>

            <div className="min-w-0">
              <p className="text-sm text-[#68776b]">
                Total Transaksi
              </p>

              <h2 className="mt-1 text-2xl font-semibold text-[#26392b]">
                {isLoading ? "..." : totalTransaksi}
              </h2>

              <p className="mt-1 text-xs text-[#879287]">
                Seluruh aktivitas stok
              </p>
            </div>
          </div>

          <div className="flex min-w-0 items-center gap-4 rounded-xl border border-[#dfe8de] bg-white p-4 shadow-sm transition-shadow hover:shadow-md sm:p-5">
            <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg bg-[#edf4ec] text-[#587653]">
              <TrendingUp size={22} strokeWidth={1.8} />
            </div>

            <div className="min-w-0">
              <p className="text-sm text-[#68776b]">
                Total Barang Masuk
              </p>

              <h2 className="mt-1 text-2xl font-semibold text-[#587653]">
                {isLoading ? "..." : totalBarangMasuk}
              </h2>

              <p className="mt-1 text-xs text-[#879287]">
                Total unit yang diterima
              </p>
            </div>
          </div>

          <div className="flex min-w-0 items-center gap-4 rounded-xl border border-[#dfe8de] bg-white p-4 shadow-sm transition-shadow hover:shadow-md sm:col-span-2 sm:p-5 xl:col-span-1">
            <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg bg-[#f8eeee] text-[#bd6969]">
              <TrendingDown size={22} strokeWidth={1.8} />
            </div>

            <div className="min-w-0">
              <p className="text-sm text-[#68776b]">
                Total Barang Keluar
              </p>

              <h2 className="mt-1 text-2xl font-semibold text-[#bd6969]">
                {isLoading ? "..." : totalBarangKeluar}
              </h2>

              <p className="mt-1 text-xs text-[#879287]">
                Total unit yang dikeluarkan
              </p>
            </div>
          </div>
        </section>

        {/* TAB JENIS STOK */}
        <div className="mb-4 flex flex-wrap items-center gap-2">
          {["Semua", "Masuk", "Keluar"].map((jenis) => (
            <button
              key={jenis}
              type="button"
              onClick={() => {
                setTab(jenis);
                setHalaman(1);
              }}
              className={`rounded-lg border px-4 py-2 text-xs font-medium transition-colors ${
                tab === jenis
                  ? "border-[#587653] bg-[#587653] text-white"
                  : "border-[#d8e3d7] bg-white text-[#526356] hover:bg-[#edf4ec]"
              }`}
            >
              {jenis === "Semua" ? "Semua" : `Stok ${jenis}`}
            </button>
          ))}
        </div>

        {/* FILTER */}
        <section className="mb-4 rounded-xl border border-[#dfe8de] bg-white p-4 shadow-sm">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-[130px_140px_minmax(180px,1fr)_minmax(180px,1fr)]">

            <div>
              <label className="mb-2 block text-xs font-medium text-[#68776b]">
                Periode
              </label>

              <select
                value={periode}
                onChange={(e) => {
                  setPeriode(e.target.value);
                  setHalaman(1);
                }}
                className="h-10 w-full rounded-lg border border-[#d8e3d7] bg-white px-3 text-sm text-[#35483a] outline-none focus:border-[#587653] focus:ring-2 focus:ring-[#587653]/10"
              >
                <option value="">Semua Periode</option>
                <option value="hari">Hari Ini</option>
                <option value="minggu">Minggu Ini</option>
                <option value="bulan">Bulan Ini</option>
              </select>
            </div>

            <div>
              <label className="mb-2 block text-xs font-medium text-[#68776b]">
                Jenis Stok
              </label>

              <select
                value={jenisStok}
                onChange={(e) => {
                  setJenisStok(e.target.value);
                  setHalaman(1);
                }}
                className="h-10 w-full rounded-lg border border-[#d8e3d7] bg-white px-3 text-sm text-[#35483a] outline-none focus:border-[#587653] focus:ring-2 focus:ring-[#587653]/10"
              >
                <option value="">Semua Jenis</option>
                <option value="Masuk">Masuk</option>
                <option value="Keluar">Keluar</option>
              </select>
            </div>

            <div>
              <label className="mb-2 block text-xs font-medium text-[#68776b]">
                Cari Barang
              </label>

              <div className="relative">
                <Search
                  size={16}
                  strokeWidth={1.8}
                  className="absolute left-3 top-1/2 -translate-y-1/2 text-[#879287]"
                />

                <input
                  type="text"
                  value={cariBarang}
                  onChange={(e) => {
                    setCariBarang(e.target.value);
                    setHalaman(1);
                  }}
                  placeholder="Nama barang..."
                  className="h-10 w-full rounded-lg border border-[#d8e3d7] bg-white pl-9 pr-3 text-sm text-[#35483a] outline-none placeholder:text-[#a0aaa0] focus:border-[#587653] focus:ring-2 focus:ring-[#587653]/10"
                />
              </div>
            </div>

            <div>
              <label className="mb-2 block text-xs font-medium text-[#68776b]">
                Cari Pemasok / Tujuan
              </label>

              <div className="relative">
                <Search
                  size={16}
                  strokeWidth={1.8}
                  className="absolute left-3 top-1/2 -translate-y-1/2 text-[#879287]"
                />

                <input
                  type="text"
                  value={cariPemasok}
                  onChange={(e) => {
                    setCariPemasok(e.target.value);
                    setHalaman(1);
                  }}
                  placeholder="Nama pemasok atau tujuan..."
                  className="h-10 w-full rounded-lg border border-[#d8e3d7] bg-white pl-9 pr-3 text-sm text-[#35483a] outline-none placeholder:text-[#a0aaa0] focus:border-[#587653] focus:ring-2 focus:ring-[#587653]/10"
                />
              </div>
            </div>
          </div>
        </section>

        {/* TABEL RIWAYAT */}
        <section className="overflow-hidden rounded-xl border border-[#dfe8de] bg-white shadow-sm">

          <div className="flex flex-col gap-2 border-b border-[#e6ece5] px-4 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-5">
            <div>
              <h2 className="text-sm font-semibold text-[#35483a]">
                Daftar Riwayat Stok
              </h2>

              <p className="mt-1 text-xs text-[#879287]">
                Menampilkan {isLoading ? "..." : dataHalaman.length} dari{" "}
                {isLoading ? "..." : dataFilter.length} transaksi
              </p>
            </div>

            <button
              type="button"
              onClick={() => void fetchRiwayat()}
              disabled={isLoading}
              className="inline-flex items-center justify-center gap-2 self-start rounded-lg border border-[#d8e3d7] px-3 py-2 text-xs font-medium text-[#526356] transition hover:bg-[#edf4ec] disabled:opacity-50 sm:self-auto"
            >
              <RefreshCw
                size={15}
                className={isLoading ? "animate-spin" : ""}
              />
              Refresh
            </button>
          </div>

          <div className="w-full overflow-x-auto">
            <table className="w-full min-w-[850px] border-collapse text-sm">
              <thead>
                <tr className="bg-[#f5f8f4] text-left text-xs text-[#68776b]">
                  <th className="border-b border-[#e3ebe1] px-4 py-4 font-medium">Tanggal</th>
                  <th className="border-b border-[#e3ebe1] px-4 py-4 font-medium">Jenis</th>
                  <th className="border-b border-[#e3ebe1] px-4 py-4 font-medium">Barang</th>
                  <th className="border-b border-[#e3ebe1] px-4 py-4 font-medium">SKU</th>
                  <th className="border-b border-[#e3ebe1] px-4 py-4 text-center font-medium">Jumlah</th>
                  <th className="border-b border-[#e3ebe1] px-4 py-4 font-medium">Pemasok / Tujuan</th>
                  <th className="border-b border-[#e3ebe1] px-4 py-4 font-medium">Catatan</th>
                  <th className="border-b border-[#e3ebe1] px-4 py-4 text-center font-medium">Aksi</th>
                </tr>
              </thead>

              <tbody>
                {isLoading && (
                  <tr>
                    <td colSpan={8} className="px-4 py-12 text-center text-sm text-[#879287]">
                      Sedang mengambil data riwayat stok...
                    </td>
                  </tr>
                )}

                {!isLoading && loadError && (
                  <tr>
                    <td colSpan={8} className="px-4 py-12 text-center text-sm text-red-500">
                      {loadError}

                      <button
                        type="button"
                        onClick={() => void fetchRiwayat()}
                        className="mx-auto mt-3 block rounded-lg bg-[#587653] px-4 py-2 text-xs font-medium text-white"
                      >
                        Coba lagi
                      </button>
                    </td>
                  </tr>
                )}

                {!isLoading && !loadError && dataHalaman.map((item) => (
                  <tr
                    key={item.id}
                    className="transition-colors hover:bg-[#f8faf7]"
                  >
                    <td className="border-b border-[#edf1eb] px-4 py-4 text-xs text-[#526356]">
                      {formatTanggal(item.tanggal)}
                    </td>

                    <td className="border-b border-[#edf1eb] px-4 py-4">
                      <span
                        className={`inline-flex rounded-full px-3 py-1 text-xs font-medium ${
                          item.jenis === "Masuk"
                            ? "bg-[#e7f3e8] text-[#587653]"
                            : "bg-[#f9eaea] text-[#bd6969]"
                        }`}
                      >
                        {item.jenis}
                      </span>
                    </td>

                    <td className="border-b border-[#edf1eb] px-4 py-4 text-xs font-medium text-[#35483a]">
                      {item.barang || "—"}
                    </td>

                    <td className="border-b border-[#edf1eb] px-4 py-4 text-xs text-[#526356]">
                      {item.sku || "—"}
                    </td>

                    <td
                      className={`border-b border-[#edf1eb] px-4 py-4 text-center text-xs font-semibold ${
                        item.jumlah >= 0
                          ? "text-[#587653]"
                          : "text-[#bd6969]"
                      }`}
                    >
                      {item.jumlah >= 0
                        ? `+${item.jumlah}`
                        : item.jumlah}
                    </td>

                    <td className="border-b border-[#edf1eb] px-4 py-4 text-xs text-[#526356]">
                      {item.pemasokTujuan}
                    </td>

                    <td className="border-b border-[#edf1eb] px-4 py-4 text-xs text-[#68776b]">
                      {item.catatan || "—"}
                    </td>

                    <td className="border-b border-[#edf1eb] px-4 py-4 text-center">
                      <button
                        type="button"
                        title="Lihat detail"
                        onClick={() =>
                          alert(
                            `Detail transaksi\nBarang: ${item.barang}\nSKU: ${item.sku}\nJenis: ${item.jenis}\nJumlah: ${item.jumlah}`
                          )
                        }
                        className="inline-flex h-8 w-8 items-center justify-center rounded-lg text-[#68776b] transition-colors hover:bg-[#edf4ec] hover:text-[#587653]"
                      >
                        <Eye size={17} strokeWidth={1.8} />
                      </button>
                    </td>
                  </tr>
                ))}

                {!isLoading && !loadError && dataHalaman.length === 0 && (
                  <tr>
                    <td
                      colSpan={8}
                      className="px-4 py-12 text-center text-sm text-[#879287]"
                    >
                      <div className="flex flex-col items-center gap-2">
                        <Search size={24} strokeWidth={1.5} />

                        <p>Data riwayat stok tidak ditemukan.</p>

                        <p className="text-xs">
                          Coba ubah kata kunci pencarian atau filter.
                        </p>
                      </div>
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>

        {/* PAGINATION */}
        <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-xs text-[#879287]">
            Halaman {halamanAktif} dari {totalHalaman}
          </p>

          <div className="flex flex-wrap items-center justify-end gap-1.5">
            <button
              type="button"
              disabled={halamanAktif === 1 || isLoading}
              onClick={() => pindahHalaman(halamanAktif - 1)}
              className="flex h-9 min-w-9 items-center justify-center rounded-lg border border-[#d8e3d7] bg-white px-3 text-sm text-[#526356] transition-colors hover:bg-[#edf4ec] disabled:cursor-not-allowed disabled:opacity-40"
            >
              ‹
            </button>

            {Array.from(
              { length: Math.min(totalHalaman, 5) },
              (_, index) => {
                const nomor =
                  totalHalaman <= 5
                    ? index + 1
                    : Math.min(
                        Math.max(halamanAktif - 2, 1),
                        totalHalaman - 4
                      ) + index;

                return (
                  <button
                    key={nomor}
                    type="button"
                    onClick={() => pindahHalaman(nomor)}
                    className={`flex h-9 min-w-9 items-center justify-center rounded-lg border px-3 text-sm transition-colors ${
                      halamanAktif === nomor
                        ? "border-[#587653] bg-[#587653] text-white"
                        : "border-[#d8e3d7] bg-white text-[#526356] hover:bg-[#edf4ec]"
                    }`}
                  >
                    {nomor}
                  </button>
                );
              }
            )}

            <button
              type="button"
              disabled={halamanAktif === totalHalaman || isLoading}
              onClick={() => pindahHalaman(halamanAktif + 1)}
              className="flex h-9 min-w-9 items-center justify-center rounded-lg border border-[#d8e3d7] bg-white px-3 text-sm text-[#526356] transition-colors hover:bg-[#edf4ec] disabled:cursor-not-allowed disabled:opacity-40"
            >
              ›
            </button>
          </div>
        </div>
      </main>
    </div>
  );
}
