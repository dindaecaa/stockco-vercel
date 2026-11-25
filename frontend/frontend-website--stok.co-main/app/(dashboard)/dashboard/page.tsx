"use client";

import { Search } from "lucide-react";

import ProfilManager from "@/components/profile/ProfilManager";
import StatCards from "@/components/dashboard/StatCards";
import StockChart from "@/components/dashboard/StockChart";
import CategoryChart from "@/components/dashboard/CategoryChart";
import ReceivingCard from "@/components/stock/ReceivingCard";

export default function DashboardPage() {
  return (
    <main className="dashboard-page">
      {/* AREA UTAMA */}
      <section className="dashboard-main">
        {/* TOPBAR */}
        <header className="dashboard-navbar">
          <label className="dashboard-search">
            <Search size={19} />

            <input
              type="search"
              placeholder="Cari barang, SKU, pemasok, atau lokasi..."
              aria-label="Cari inventori"
            />
          </label>

          <div className="dashboard-navbar-right">
            <div className="dashboard-profile">
              <ProfilManager />
            </div>
          </div>
        </header>

        {/* KONTEN DASHBOARD */}
        <div className="dashboard-content-new">
          {/* HEADER DAN BANNER */}
          <div className="dashboard-welcome-row">
            <div className="dashboard-welcome">
              <span className="dashboard-breadcrumb">
                Dashboard
              </span>

              <h1>Selamat Datang, Manager!</h1>

              <p>
                Berikut ringkasan kondisi inventori hari ini.
              </p>
            </div>

            {/* BANNER INFORMASI */}
            <section className="dashboard-banner">
              <div className="banner-text">
                <span className="banner-label">
                  INFORMASI INVENTORI
                </span>

                <strong>
                  Stok terpantau,
                  <br />
                  operasional lebih teratur.
                </strong>

                <p>
                  Pantau persediaan dan penerimaan barang
                  <br className="banner-desktop-break" />
                  dengan lebih mudah dalam satu sistem.
                </p>
              </div>
            </section>
          </div>

          {/* RINGKASAN STOK */}
          <StatCards />

          {/* GRAFIK PERGERAKAN DAN KATEGORI */}
          <section className="dashboard-chart-row">
            <StockChart />
            <CategoryChart />
          </section>

          {/* TABEL GABUNGAN STOK MASUK & STOK KELUAR */}
          <ReceivingCard />
        </div>
      </section>
    </main>
  );
}