
"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useState } from "react";

const menuItems = [
  {
    title: "Dashboard",
    href: "/dashboard",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <rect x="3" y="3" width="8" height="8" rx="1" />
        <rect x="13" y="3" width="8" height="5" rx="1" />
        <rect x="13" y="10" width="8" height="11" rx="1" />
        <rect x="3" y="13" width="8" height="8" rx="1" />
      </svg>
    ),
  },
  {
    title: "Analisis Stok",
    href: "/analisis-stok",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M3 3v18h18" />
        <path d="m7 14 4-4 4 3 6-7" />
      </svg>
    ),
  },
  {
    title: "SKU Database",
    href: "/sku-database",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <rect x="3" y="4" width="18" height="16" rx="2" />
        <path d="M7 8h10M7 12h10M7 16h5" />
      </svg>
    ),
  },
  {
    title: "Stok Masuk",
    href: "/stok-masuk",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M12 16V4m-5 5 5-5 5 5" />
        <path d="M4 16v4h16v-4" />
      </svg>
    ),
  },
  {
    title: "Stok Keluar",
    href: "/stok-keluar",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M12 4v12m-5-5 5 5 5-5" />
        <path d="M4 16v4h16v-4" />
      </svg>
    ),
  },
  {
    title: "Riwayat Stok",
    href: "/riwayat-stok",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5l3 2" />
      </svg>
    ),
  },
  {
    title: "Data Pemasok",
    href: "/data-pemasok",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <circle cx="9" cy="8" r="3" />
        <path d="M3 20v-2a6 6 0 0 1 12 0v2M16 5a3 3 0 0 1 0 6m2 3a5 5 0 0 1 3 4v2" />
      </svg>
    ),
  },
  {
    title: "Data Barang Rusak",
    href: "/data-barang-rusak",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M12 3 22 20H2L12 3Z" />
        <path d="M12 9v5m0 3h.01" />
      </svg>
    ),
  },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const [showLogout, setShowLogout] = useState(false);

  const isActive = (href: string) => {
    if (href === "/dashboard") {
      return pathname === href;
    }

    return pathname === href || pathname.startsWith(`${href}/`);
  };

  const handleLogout = () => {
    // Hapus token sesi login
    localStorage.removeItem("stockco_token");

    // Tutup modal konfirmasi
    setShowLogout(false);

    // Pindah ke login dan refresh state aplikasi
    router.replace("/login");
    router.refresh();
  };

  return (
    <>
      <aside className="sidebar fixed left-0 top-0 z-50 h-screen w-[250px]">
        {/* Logo */}
        <div className="dashboard-logo">
          <img src="/stock-logo.png" alt="Stock.co" />
        </div>

        {/* Menu Navigasi */}
        <nav className="sidebar-menu" aria-label="Menu utama">
          {menuItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={`sidebar-item ${
                isActive(item.href) ? "active" : ""
              }`}
              aria-current={isActive(item.href) ? "page" : undefined}
            >
              <span className="menu-icon">{item.icon}</span>
              <span>{item.title}</span>
            </Link>
          ))}
        </nav>

        {/* Tombol Logout */}
        <button
          type="button"
          className="logout-button"
          onClick={() => setShowLogout(true)}
        >
          <span className="menu-icon">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
            >
              <path d="M10 17l5-5-5-5m5 5H3" />
              <path d="M12 3h7a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-7" />
            </svg>
          </span>
          <span>Logout</span>
        </button>
      </aside>

      {/* Popup Konfirmasi Logout */}
      {showLogout && (
        <div
          className="logout-overlay"
          onClick={() => setShowLogout(false)}
        >
          <div
            className="logout-modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="logout-title"
            onClick={(event) => event.stopPropagation()}
          >
            <h2 id="logout-title">Konfirmasi Logout</h2>

            <p>
              Apakah kamu yakin ingin keluar dari akun Stock.co?
            </p>

            <div className="logout-modal-actions">
              <button
                type="button"
                className="logout-cancel-button"
                onClick={() => setShowLogout(false)}
              >
                Batal
              </button>

              <button
                type="button"
                className="logout-confirm-button"
                onClick={handleLogout}
              >
                Ya, Logout
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
