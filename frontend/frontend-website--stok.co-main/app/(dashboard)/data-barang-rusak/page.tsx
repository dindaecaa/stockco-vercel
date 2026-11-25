
"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Search,
  AlertTriangle,
  Package,
  Clock3,
  CheckCircle2,
  XCircle,
  ChevronLeft,
  ChevronRight,
  Eye,
  MapPin,
  CalendarDays,
  RefreshCw,
  X,
  RotateCcw,
  ClipboardList,
} from "lucide-react";

import ProfilManager from "@/components/profile/ProfilManager";
import { apiFetch } from "@/lib/api";

type BarangRusak = {
  id: number;
  product_id: number | null;
  product_name: string;
  product_sku: string | null;
  location: string | null;
  quantity: number;
  reason: string;
  note: string | null;
  status: string;
  photo_key: string | null;
  created_at: string;
};

type FilterStatus =
  | "Semua"
  | "Belum ditindaklanjuti"
  | "Disetujui"
  | "Ditolak";

const PAGE_SIZE = 6;

function formatTanggal(value: string) {
  if (!value) return "-";

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) return value;

  return date.toLocaleString("id-ID", {
    day: "2-digit",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function labelStatus(status: string) {
  if (status === "Disetujui") return "Disetujui";
  if (status === "Ditolak") return "Ditolak";
  return "Menunggu Persetujuan";
}

function statusStyle(status: string) {
  if (status === "Disetujui") {
    return "bg-[#eaf5ee] text-[#43865d]";
  }

  if (status === "Ditolak") {
    return "bg-[#fdf0ef] text-[#c96767]";
  }

  return "bg-[#fff6e5] text-[#b88936]";
}

export default function DataBarangRusakPage() {
  const [data, setData] = useState<BarangRusak[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] =
    useState<FilterStatus>("Semua");
  const [halaman, setHalaman] = useState(1);
  const [selectedItem, setSelectedItem] =
    useState<BarangRusak | null>(null);
  const [processingId, setProcessingId] = useState<number | null>(
    null
  );

  // ==========================================
  // FETCH DATA
  // ==========================================

  const fetchData = useCallback(async () => {
    try {
      setLoading(true);
      setError("");

      const response = await apiFetch("damaged-items", {
        method: "GET",
        cache: "no-store",
      });

      const result = await response.json();

      if (!response.ok || !result.success) {
        throw new Error(
          result.message || "Gagal mengambil data barang rusak."
        );
      }

      setData(Array.isArray(result.data) ? result.data : []);
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Terjadi kesalahan saat mengambil data."
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void fetchData();
  }, [fetchData]);

  // ==========================================
  // STATISTIK
  // ==========================================

  const menunggu = data.filter(
    (item) => item.status === "Belum ditindaklanjuti"
  ).length;

  const disetujui = data.filter(
    (item) => item.status === "Disetujui"
  ).length;

  const ditolak = data.filter(
    (item) => item.status === "Ditolak"
  ).length;

  // ==========================================
  // FILTER DAN SEARCH
  // ==========================================

  const filteredData = useMemo(() => {
    const keyword = search.trim().toLowerCase();

    return data.filter((item) => {
      const cocokPencarian =
        !keyword ||
        [
          item.product_name,
          item.product_sku || "",
          item.location || "",
          item.reason,
          item.note || "",
        ].some((value) =>
          String(value).toLowerCase().includes(keyword)
        );

      const cocokStatus =
        statusFilter === "Semua" ||
        item.status === statusFilter;

      return cocokPencarian && cocokStatus;
    });
  }, [data, search, statusFilter]);

  // ==========================================
  // PAGINATION
  // ==========================================

  const totalPages = Math.max(
    1,
    Math.ceil(filteredData.length / PAGE_SIZE)
  );

  const currentPage = Math.min(halaman, totalPages);

  const pageData = filteredData.slice(
    (currentPage - 1) * PAGE_SIZE,
    currentPage * PAGE_SIZE
  );

  const changeFilter = (value: FilterStatus) => {
    setStatusFilter(value);
    setHalaman(1);
  };

  const changeSearch = (value: string) => {
    setSearch(value);
    setHalaman(1);
  };

  // ==========================================
  // PERSETUJUAN LAPORAN
  // ==========================================

  const handleDecision = async (
    item: BarangRusak,
    status: "Disetujui" | "Ditolak"
  ) => {
    const action =
      status === "Disetujui" ? "menyetujui" : "menolak";

    const confirmed = window.confirm(
      `Apakah Anda yakin ingin ${action} laporan ${item.product_name}?`
    );

    if (!confirmed) return;

    try {
      setProcessingId(item.id);

      const response = await apiFetch(
        `damaged-items/${item.id}/status`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ status }),
        }
      );

      const result = await response.json();

      if (!response.ok || !result.success) {
        throw new Error(
          result.message || "Gagal memperbarui status laporan."
        );
      }

      await fetchData();
      setSelectedItem(null);

      window.alert(`Laporan berhasil ${action}.`);
    } catch (err) {
      window.alert(
        err instanceof Error
          ? err.message
          : "Terjadi kesalahan saat memperbarui status."
      );
    } finally {
      setProcessingId(null);
    }
  };

  // ==========================================
  // KARTU STATISTIK
  // ==========================================

  const statistics = [
    {
      title: "Total Laporan",
      value: data.length,
      description: "Semua laporan barang rusak",
      icon: Package,
      iconStyle: "bg-[#f0edff] text-[#8270cf]",
      filter: "Semua" as FilterStatus,
    },
    {
      title: "Menunggu Persetujuan",
      value: menunggu,
      description: "Perlu ditinjau manager",
      icon: Clock3,
      iconStyle: "bg-[#fff5e5] text-[#c99a45]",
      filter: "Belum ditindaklanjuti" as FilterStatus,
    },
    {
      title: "Disetujui",
      value: disetujui,
      description: "Laporan telah disetujui",
      icon: CheckCircle2,
      iconStyle: "bg-[#eaf5ee] text-[#43865d]",
      filter: "Disetujui" as FilterStatus,
    },
    {
      title: "Ditolak",
      value: ditolak,
      description: "Laporan tidak disetujui",
      icon: XCircle,
      iconStyle: "bg-[#fdf0ef] text-[#cf6e6e]",
      filter: "Ditolak" as FilterStatus,
    },
  ];

  return (
    <div className="min-h-screen bg-[#f5f8f6]">
      {/* PADDING KIRI DIHAPUS AGAR TIDAK ADA RUANG KOSONG */}
      <main className="min-h-screen w-full">
        {/* HEADER */}
        <header className="sticky top-0 z-30 flex min-h-[85px] items-center justify-between gap-4 border-b border-[#e7eee9] bg-[#f8faf8] px-8 py-5">
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-[#24352d]">
              Data Barang Rusak
            </h1>
            <p className="mt-1 text-sm text-[#87958d]">
              Pantau dan kelola laporan kerusakan barang inventaris.
            </p>
          </div>

          <ProfilManager />
        </header>

        <div className="space-y-5 p-7">
          {/* BANNER */}
          <section className="relative overflow-hidden rounded-2xl border border-[#dcece1] bg-gradient-to-r from-[#f0f8f2] to-[#e7f3e9] px-7 py-6">
            <div className="relative z-10 flex items-center justify-between gap-5">
              <div className="flex items-center gap-5">
                <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-[#38694f] text-white shadow-sm">
                  <AlertTriangle size={25} />
                </div>

                <div>
                  <h2 className="text-lg font-bold text-[#294b3a]">
                    Kelola laporan kerusakan barang
                  </h2>

                  <p className="mt-1 text-sm leading-6 text-[#81948a]">
                    Periksa laporan kerusakan yang dikirim oleh staff
                    dan tentukan tindak lanjut untuk setiap laporan.
                  </p>
                </div>
              </div>

              <div className="hidden h-16 w-16 shrink-0 items-center justify-center rounded-2xl border border-[#cfe3d4] text-[#b7d7c0] sm:flex">
                <Package size={35} strokeWidth={1.5} />
              </div>
            </div>

            <div className="pointer-events-none absolute -right-8 -top-14 h-44 w-44 rounded-full border-[22px] border-[#dcecdf]/60" />
            <div className="pointer-events-none absolute -bottom-24 right-40 h-40 w-40 rounded-full bg-[#dcecdf]/50" />
          </section>

          {/* STATISTIK */}
          <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {statistics.map((stat) => {
              const Icon = stat.icon;
              const isActive = statusFilter === stat.filter;

              return (
                <button
                  key={stat.title}
                  type="button"
                  onClick={() => changeFilter(stat.filter)}
                  className={`group relative overflow-hidden rounded-2xl border bg-white p-5 text-left shadow-[0_2px_8px_rgba(30,60,40,0.04)] transition duration-200 hover:-translate-y-0.5 hover:shadow-md ${
                    isActive
                      ? "border-[#78ae89] bg-[#fbfefb]"
                      : "border-[#e7eee9] hover:border-[#b7d5bf]"
                  }`}
                >
                  <div className="flex items-center gap-4">
                    <span
                      className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-xl ${stat.iconStyle}`}
                    >
                      <Icon size={21} />
                    </span>

                    <div className="min-w-0">
                      <span className="block text-xs font-medium text-[#84938a]">
                        {stat.title}
                      </span>

                      <strong className="mt-1 block text-2xl font-bold tracking-tight text-[#293a31]">
                        {stat.value}
                      </strong>

                      <p className="mt-1 text-[11px] text-[#9aa79f]">
                        {stat.description}
                      </p>
                    </div>
                  </div>

                  {isActive && (
                    <span className="absolute bottom-0 left-5 right-5 h-[3px] rounded-t-full bg-[#548967]" />
                  )}
                </button>
              );
            })}
          </section>

          {/* TABEL UTAMA */}
          <section className="overflow-hidden rounded-2xl border border-[#e7eee9] bg-white shadow-[0_2px_10px_rgba(30,60,40,0.035)]">
            {/* JUDUL TABEL */}
            <div className="flex flex-wrap items-center justify-between gap-4 border-b border-[#edf1ee] px-6 py-5">
              <div>
                <h2 className="text-base font-bold text-[#293a31]">
                  Riwayat Laporan Barang Rusak
                </h2>

                <p className="mt-1 text-xs text-[#91a097]">
                  Daftar laporan kerusakan yang dikirim oleh staff.
                </p>
              </div>

              <div className="flex items-center gap-2 rounded-lg border border-[#dcece1] bg-[#f5faf6] px-3 py-2 text-xs font-semibold text-[#477b58]">
                <ClipboardList size={16} />
                {filteredData.length} data
              </div>
            </div>

            {/* SEARCH DAN FILTER */}
            <div className="flex flex-wrap items-center gap-3 px-6 py-4">
              <label className="flex min-w-[220px] max-w-[460px] flex-1 items-center gap-3 rounded-xl border border-[#dfe9e2] bg-[#fbfdfb] px-3.5 py-3 transition focus-within:border-[#79ae88] focus-within:ring-2 focus-within:ring-[#e7f2e9]">
                <Search size={18} className="shrink-0 text-[#91a097]" />

                <input
                  type="search"
                  value={search}
                  onChange={(event) =>
                    changeSearch(event.target.value)
                  }
                  placeholder="Cari nama barang, SKU, lokasi..."
                  className="w-full bg-transparent text-sm text-[#43544a] outline-none placeholder:text-[#a1ada5]"
                />

                {search && (
                  <button
                    type="button"
                    onClick={() => changeSearch("")}
                    aria-label="Hapus pencarian"
                    className="text-[#9aa79f] transition hover:text-[#477b58]"
                  >
                    <X size={16} />
                  </button>
                )}
              </label>

              <label className="flex items-center gap-2 rounded-xl border border-[#dfe9e2] bg-white px-3.5">
                <span className="text-sm text-[#819087]">
                  Status:
                </span>

                <select
                  value={statusFilter}
                  onChange={(event) =>
                    changeFilter(event.target.value as FilterStatus)
                  }
                  className="bg-transparent py-3 text-sm font-medium text-[#53645a] outline-none"
                >
                  <option value="Semua">Semua status</option>
                  <option value="Belum ditindaklanjuti">
                    Menunggu persetujuan
                  </option>
                  <option value="Disetujui">Disetujui</option>
                  <option value="Ditolak">Ditolak</option>
                </select>
              </label>

              <button
                type="button"
                onClick={() => void fetchData()}
                disabled={loading}
                className="inline-flex items-center gap-2 rounded-xl border border-[#dcece1] bg-[#f5faf6] px-4 py-3 text-sm font-semibold text-[#477b58] transition hover:bg-[#eaf5ed] disabled:cursor-not-allowed disabled:opacity-50"
              >
                <RefreshCw
                  size={16}
                  className={loading ? "animate-spin" : ""}
                />
                Refresh
              </button>
            </div>

            {/* LOADING */}
            {loading && (
              <div className="px-6 py-16 text-center text-sm text-[#87958d]">
                <RefreshCw
                  size={26}
                  className="mx-auto mb-3 animate-spin text-[#548967]"
                />
                Memuat laporan barang rusak...
              </div>
            )}

            {/* ERROR */}
            {!loading && error && (
              <div className="mx-6 mb-6 rounded-xl border border-red-100 bg-red-50 p-5 text-sm text-red-700">
                <div className="flex items-start gap-3">
                  <AlertTriangle size={20} className="mt-0.5 shrink-0" />

                  <div>
                    <strong>Data belum dapat dimuat.</strong>
                    <p className="mt-1">{error}</p>

                    <button
                      type="button"
                      onClick={() => void fetchData()}
                      className="mt-3 inline-flex items-center gap-2 rounded-lg bg-[#38694f] px-4 py-2 font-semibold text-white transition hover:bg-[#2e593f]"
                    >
                      <RotateCcw size={15} />
                      Coba lagi
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* DATA */}
            {!loading && !error && (
              <>
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[950px] text-left">
                    <thead className="bg-[#f7faf7] text-[11px] font-semibold text-[#7d8e83]">
                      <tr>
                        <th className="px-5 py-4">No.</th>
                        <th className="px-5 py-4">Nama Barang</th>
                        <th className="px-5 py-4">SKU</th>
                        <th className="px-5 py-4">Lokasi</th>
                        <th className="px-5 py-4">Jumlah</th>
                        <th className="px-5 py-4">Tanggal Laporan</th>
                        <th className="px-5 py-4">Status</th>
                        <th className="px-5 py-4 text-center">Aksi</th>
                      </tr>
                    </thead>

                    <tbody className="divide-y divide-[#edf1ee] text-sm">
                      {pageData.map((item, index) => (
                        <tr
                          key={item.id}
                          className="transition hover:bg-[#f8fbf8]"
                        >
                          <td className="px-5 py-4 text-xs text-[#9aa79f]">
                            {(currentPage - 1) * PAGE_SIZE +
                              index +
                              1}
                          </td>

                          <td className="px-5 py-4">
                            <div className="font-semibold text-[#35483b]">
                              {item.product_name}
                            </div>
                            <div className="mt-1 max-w-[190px] truncate text-[11px] text-[#9aa79f]">
                              {item.reason}
                            </div>
                          </td>

                          <td className="px-5 py-4 text-xs text-[#718078]">
                            {item.product_sku || "—"}
                          </td>

                          <td className="px-5 py-4 text-xs text-[#718078]">
                            <span className="flex items-center gap-1.5">
                              <MapPin
                                size={14}
                                className="text-[#8da195]"
                              />
                              {item.location || "—"}
                            </span>
                          </td>

                          <td className="px-5 py-4 text-xs font-semibold text-[#53645a]">
                            {item.quantity}
                          </td>

                          <td className="px-5 py-4 text-xs text-[#7f8e84]">
                            {formatTanggal(item.created_at)}
                          </td>

                          <td className="px-5 py-4">
                            <span
                              className={`inline-flex items-center gap-1.5 whitespace-nowrap rounded-full px-3 py-1.5 text-[11px] font-semibold ${statusStyle(
                                item.status
                              )}`}
                            >
                              <span className="h-1.5 w-1.5 rounded-full bg-current" />
                              {labelStatus(item.status)}
                            </span>
                          </td>

                          <td className="px-5 py-4 text-center">
                            <button
                              type="button"
                              onClick={() => setSelectedItem(item)}
                              aria-label={`Lihat detail ${item.product_name}`}
                              className="inline-flex items-center gap-1.5 rounded-lg border border-[#dcece1] px-3 py-2 text-xs font-semibold text-[#477b58] transition hover:bg-[#edf6ef]"
                            >
                              <Eye size={15} />
                              Detail
                            </button>
                          </td>
                        </tr>
                      ))}

                      {pageData.length === 0 && (
                        <tr>
                          <td
                            colSpan={8}
                            className="px-6 py-16 text-center"
                          >
                            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-[#edf6ef] text-[#548967]">
                              <Package size={27} />
                            </div>

                            <strong className="mt-4 block text-sm text-[#53645a]">
                              Belum ada laporan ditemukan
                            </strong>

                            <span className="mt-1 block text-xs text-[#9aa79f]">
                              Coba ubah pencarian atau filter status.
                            </span>

                            <button
                              type="button"
                              onClick={() => {
                                changeSearch("");
                                changeFilter("Semua");
                              }}
                              className="mt-4 text-xs font-semibold text-[#477b58] transition hover:text-[#294b3a]"
                            >
                              Reset filter
                            </button>
                          </td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>

                {/* PAGINATION */}
                <footer className="flex flex-wrap items-center justify-between gap-3 border-t border-[#edf1ee] px-6 py-4">
                  <p className="text-xs text-[#8b9990]">
                    Menampilkan{" "}
                    <strong className="text-[#53645a]">
                      {pageData.length
                        ? (currentPage - 1) * PAGE_SIZE + 1
                        : 0}
                      –
                      {(currentPage - 1) * PAGE_SIZE +
                        pageData.length}
                    </strong>{" "}
                    dari{" "}
                    <strong className="text-[#53645a]">
                      {filteredData.length}
                    </strong>{" "}
                    data
                  </p>

                  <nav className="flex items-center gap-1">
                    <button
                      type="button"
                      disabled={currentPage <= 1}
                      onClick={() =>
                        setHalaman((page) => Math.max(1, page - 1))
                      }
                      aria-label="Halaman sebelumnya"
                      className="rounded-lg border border-[#e1eae3] p-2 text-[#718078] transition hover:bg-[#edf6ef] hover:text-[#477b58] disabled:cursor-not-allowed disabled:opacity-30"
                    >
                      <ChevronLeft size={17} />
                    </button>

                    {Array.from(
                      { length: totalPages },
                      (_, index) => index + 1
                    ).map((page) => (
                      <button
                        type="button"
                        key={page}
                        onClick={() => setHalaman(page)}
                        className={`h-9 min-w-9 rounded-lg px-2 text-xs font-medium transition ${
                          currentPage === page
                            ? "bg-[#38694f] text-white shadow-sm"
                            : "text-[#718078] hover:bg-[#edf6ef] hover:text-[#477b58]"
                        }`}
                      >
                        {page}
                      </button>
                    ))}

                    <button
                      type="button"
                      disabled={currentPage >= totalPages}
                      onClick={() =>
                        setHalaman((page) =>
                          Math.min(totalPages, page + 1)
                        )
                      }
                      aria-label="Halaman berikutnya"
                      className="rounded-lg border border-[#e1eae3] p-2 text-[#718078] transition hover:bg-[#edf6ef] hover:text-[#477b58] disabled:cursor-not-allowed disabled:opacity-30"
                    >
                      <ChevronRight size={17} />
                    </button>
                  </nav>
                </footer>
              </>
            )}
          </section>

          <p className="pb-2 text-center text-[11px] text-[#a0aca4]">
            Stock.co • Sistem Manajemen Inventaris
          </p>
        </div>
      </main>

      {/* MODAL DETAIL LAPORAN */}
      {selectedItem && (
        <div
          className="fixed inset-0 z-[100] flex items-center justify-center bg-[#203b2d]/35 p-4 backdrop-blur-[2px]"
          onClick={() => setSelectedItem(null)}
        >
          <section
            className="max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-2xl border border-[#e5eee7] bg-white shadow-2xl"
            onClick={(event) => event.stopPropagation()}
          >
            {/* HEADER MODAL */}
            <div className="flex items-start justify-between gap-4 border-b border-[#edf1ee] px-6 py-5">
              <div>
                <span className="inline-flex items-center gap-1.5 text-xs font-semibold uppercase tracking-wider text-[#548967]">
                  <AlertTriangle size={14} />
                  Detail Laporan
                </span>

                <h2 className="mt-2 text-xl font-bold text-[#293a31]">
                  {selectedItem.product_name}
                </h2>

                <p className="mt-1 text-xs text-[#96a39a]">
                  Laporan #{selectedItem.id}
                </p>
              </div>

              <button
                type="button"
                onClick={() => setSelectedItem(null)}
                className="rounded-xl p-2 text-[#96a39a] transition hover:bg-[#f0f5f1] hover:text-[#477b58]"
                aria-label="Tutup detail"
              >
                <X size={20} />
              </button>
            </div>

            <div className="space-y-5 p-6">
              {/* INFORMASI BARANG */}
              <div className="grid grid-cols-2 gap-3">
                <div className="rounded-xl border border-[#e8efe9] bg-[#f8faf8] p-4">
                  <span className="text-xs font-medium text-[#96a39a]">
                    SKU
                  </span>
                  <strong className="mt-1 block text-sm text-[#35483b]">
                    {selectedItem.product_sku || "—"}
                  </strong>
                </div>

                <div className="rounded-xl border border-[#e8efe9] bg-[#f8faf8] p-4">
                  <span className="text-xs font-medium text-[#96a39a]">
                    Jumlah Rusak
                  </span>
                  <strong className="mt-1 block text-sm text-[#35483b]">
                    {selectedItem.quantity} unit
                  </strong>
                </div>

                <div className="rounded-xl border border-[#e8efe9] bg-[#f8faf8] p-4">
                  <span className="text-xs font-medium text-[#96a39a]">
                    Lokasi
                  </span>
                  <strong className="mt-1 flex items-center gap-1 text-sm text-[#35483b]">
                    <MapPin size={14} className="text-[#548967]" />
                    {selectedItem.location || "—"}
                  </strong>
                </div>

                <div className="rounded-xl border border-[#e8efe9] bg-[#f8faf8] p-4">
                  <span className="text-xs font-medium text-[#96a39a]">
                    Tanggal
                  </span>
                  <strong className="mt-1 flex items-center gap-1 text-sm text-[#35483b]">
                    <CalendarDays size={14} className="text-[#548967]" />
                    {formatTanggal(selectedItem.created_at)}
                  </strong>
                </div>
              </div>

              {/* PENYEBAB */}
              <div>
                <span className="text-xs font-bold tracking-wide text-[#829188]">
                  PENYEBAB KERUSAKAN
                </span>
                <p className="mt-2 rounded-xl border border-[#e8efe9] bg-[#f8faf8] p-4 text-sm leading-6 text-[#53645a]">
                  {selectedItem.reason}
                </p>
              </div>

              {/* CATATAN */}
              <div>
                <span className="text-xs font-bold tracking-wide text-[#829188]">
                  CATATAN STAFF
                </span>
                <p className="mt-2 rounded-xl border border-[#e8efe9] bg-[#f8faf8] p-4 text-sm leading-6 text-[#53645a]">
                  {selectedItem.note || "Tidak ada catatan tambahan."}
                </p>
              </div>

              {/* STATUS */}
              <div>
                <span className="text-xs font-bold tracking-wide text-[#829188]">
                  STATUS LAPORAN
                </span>
                <div className="mt-2">
                  <span
                    className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold ${statusStyle(
                      selectedItem.status
                    )}`}
                  >
                    <span className="h-1.5 w-1.5 rounded-full bg-current" />
                    {labelStatus(selectedItem.status)}
                  </span>
                </div>
              </div>
            </div>

            {/* TOMBOL AKSI */}
            {selectedItem.status === "Belum ditindaklanjuti" && (
              <div className="flex flex-wrap justify-end gap-3 border-t border-[#edf1ee] bg-[#f8faf8] px-6 py-5">
                <button
                  type="button"
                  disabled={processingId === selectedItem.id}
                  onClick={() =>
                    handleDecision(selectedItem, "Ditolak")
                  }
                  className="rounded-xl border border-[#f0d7d5] bg-white px-4 py-2.5 text-sm font-semibold text-[#c96767] transition hover:bg-[#fdf3f2] disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Tolak Laporan
                </button>

                <button
                  type="button"
                  disabled={processingId === selectedItem.id}
                  onClick={() =>
                    handleDecision(selectedItem, "Disetujui")
                  }
                  className="rounded-xl bg-[#38694f] px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:bg-[#2e593f] disabled:cursor-not-allowed disabled:opacity-50"
                >
                  {processingId === selectedItem.id
                    ? "Memproses..."
                    : "Setujui Laporan"}
                </button>
              </div>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
