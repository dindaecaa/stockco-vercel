
"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { API_BASE_URL, apiFetch } from "@/lib/api";

type ProfileData = {
  nama: string;
  email: string;
  telepon: string;
  foto: string;
};

type ProfileApiResponse = {
  success: boolean;
  message?: string;
  data?: {
    id: number;
    name: string;
    email: string;
    phone?: string | null;
    profile_photo?: string | null;
  };
};

type StockAlert = {
  product_id: number;
  product_name: string;
  sku: string | null;
  stock: number;
  minimum_stock: number;
  unit: string | null;
  location: string | null;
  alert_type: "out_of_stock" | "low_stock";
};

type StockAlertsApiResponse = {
  success: boolean;
  message?: string;
  data?: {
    total: number;
    data: StockAlert[];
  };
};

type ReceivingItem = {
  id: number;
  product_name: string;
  product_sku: string | null;
  quantity: number;
  unit: string | null;
  location: string | null;
  supplier_name: string | null;
  transaction_date: string | null;
  created_at: string;
};

type ReceivingApiResponse = {
  success: boolean;
  message?: string;
  data?: ReceivingItem[];
};

type NotificationItem = {
  id: string;
  type: "stock" | "receiving";
  title: string;
  description: string;
  date: string;
};

const API_ORIGIN = API_BASE_URL.replace(/\/api\/?$/, "");

const emptyProfile: ProfileData = {
  nama: "",
  email: "",
  telepon: "",
  foto: "",
};

function getPhotoUrl(photo: string | null | undefined): string {
  if (!photo) return "";

  if (photo.startsWith("http://") || photo.startsWith("https://")) {
    return photo;
  }

  return `${API_ORIGIN}${photo.startsWith("/") ? "" : "/"}${photo}`;
}

function formatNotificationDate(value: string | null | undefined): string {
  if (!value) return "";

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return "";
  }

  return date.toLocaleString("id-ID", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function ProfilManager() {
  const pathname = usePathname();

  const [profile, setProfile] = useState<ProfileData>(emptyProfile);
  const [showNotification, setShowNotification] = useState(false);

  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [notificationLoading, setNotificationLoading] = useState(true);
  const [notificationError, setNotificationError] = useState("");

  // ==========================================
  // LOAD PROFILE
  // ==========================================

  const loadProfile = useCallback(async () => {
    try {
      const response = await apiFetch("auth/profile");
      const result: ProfileApiResponse = await response.json();

      if (!response.ok || !result.success || !result.data) {
        throw new Error(
          result.message || "Gagal mengambil data profil."
        );
      }

      setProfile({
        nama: result.data.name,
        email: result.data.email,
        telepon: result.data.phone ?? "",
        foto: getPhotoUrl(result.data.profile_photo),
      });
    } catch (error) {
      console.error("Gagal memuat profil manager:", error);
    }
  }, []);

  // ==========================================
  // LOAD NOTIFICATIONS
  // ==========================================

  const loadNotifications = useCallback(async () => {
    setNotificationLoading(true);
    setNotificationError("");

    const results = await Promise.allSettled([
      apiFetch("dashboard/stock-alerts").then(async (response) => {
        const result: StockAlertsApiResponse = await response.json();

        if (!response.ok || !result.success) {
          throw new Error(
            result.message || "Gagal mengambil notifikasi stok."
          );
        }

        return result.data?.data ?? [];
      }),

      apiFetch("stock-movements/today").then(async (response) => {
        const result: ReceivingApiResponse = await response.json();

        if (!response.ok || !result.success) {
          throw new Error(
            result.message || "Gagal mengambil penerimaan barang."
          );
        }

        return result.data ?? [];
      }),
    ]);

    const nextNotifications: NotificationItem[] = [];
    const errors: string[] = [];

    // STOCK ALERTS
    const stockResult = results[0];

    if (stockResult.status === "fulfilled") {
      stockResult.value.forEach((item) => {
        const isOutOfStock = item.alert_type === "out_of_stock";

        nextNotifications.push({
          id: `stock-${item.product_id}`,
          type: "stock",
          title: isOutOfStock
            ? "Stok barang habis"
            : "Stok barang menipis",
          description: `${item.product_name} (${item.sku || "Tanpa SKU"}) — Stok: ${item.stock} ${item.unit || "unit"}. Minimum: ${item.minimum_stock}.`,
          date: "",
        });
      });
    } else {
      errors.push("Notifikasi stok gagal dimuat.");
      console.error("Gagal mengambil notifikasi stok:", stockResult.reason);
    }

    // TODAY'S RECEIVING
    const receivingResult = results[1];

    if (receivingResult.status === "fulfilled") {
      receivingResult.value.forEach((item) => {
        nextNotifications.push({
          id: `receiving-${item.id}`,
          type: "receiving",
          title: "Penerimaan barang",
          description: `${item.product_name} — ${item.quantity} ${item.unit || "unit"}${item.supplier_name ? ` dari ${item.supplier_name}` : ""}.`,
          date: formatNotificationDate(
            item.transaction_date || item.created_at
          ),
        });
      });
    } else {
      errors.push("Penerimaan barang gagal dimuat.");
      console.error(
        "Gagal mengambil penerimaan barang:",
        receivingResult.reason
      );
    }

    setNotifications(nextNotifications);
    setNotificationError(errors.join(" "));
    setNotificationLoading(false);
  }, []);

  // ==========================================
  // INITIAL LOAD
  // ==========================================

  useEffect(() => {
    loadProfile();
    loadNotifications();

    window.addEventListener(
      "profilManagerUpdated",
      loadProfile
    );

    return () => {
      window.removeEventListener(
        "profilManagerUpdated",
        loadProfile
      );
    };
  }, [loadProfile, loadNotifications]);

  // ==========================================
  // RENDER
  // ==========================================

  return (
    <div className="profile-manager-header">

      {/* NOTIFICATION */}
      <div
        className="profile-notification"
        onClick={() => setShowNotification((previous) => !previous)}
        style={{
          cursor: "pointer",
          position: "relative",
        }}
      >
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M18 8C18 4.686 15.314 2 12 2C8.686 2 6 4.686 6 8C6 14 3 14 3 16H21C21 14 18 14 18 8Z"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
            strokeLinejoin="round"
          />

          <path
            d="M10 20C10.5 21 11.2 22 12 22C12.8 22 13.5 21 14 20"
            stroke="currentColor"
            strokeWidth="1.8"
            strokeLinecap="round"
          />
        </svg>

        {/* DYNAMIC NOTIFICATION BADGE */}
        {notifications.length > 0 && (
          <span
            style={{
              position: "absolute",
              top: "-4px",
              right: "-4px",
              background: "#e74c3c",
              color: "white",
              minWidth: "16px",
              height: "16px",
              padding: "0 3px",
              borderRadius: "50%",
              fontSize: "10px",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            {notifications.length > 99 ? "99+" : notifications.length}
          </span>
        )}

        {/* NOTIFICATION DROPDOWN */}
        {showNotification && (
          <div
            onClick={(event) => event.stopPropagation()}
            style={{
              position: "absolute",
              top: "35px",
              right: "0",
              width: "320px",
              maxWidth: "85vw",
              maxHeight: "400px",
              overflowY: "auto",
              background: "white",
              borderRadius: "10px",
              boxShadow: "0 4px 15px rgba(0,0,0,0.15)",
              padding: "16px",
              zIndex: 1000,
              color: "#333",
            }}
          >
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                marginBottom: "12px",
              }}
            >
              <h3
                style={{
                  margin: 0,
                  fontSize: "16px",
                }}
              >
                Notifikasi
              </h3>

              <button
                type="button"
                onClick={loadNotifications}
                disabled={notificationLoading}
                style={{
                  border: "none",
                  background: "transparent",
                  color: "#2563eb",
                  cursor: "pointer",
                  fontSize: "12px",
                }}
              >
                {notificationLoading ? "Memuat..." : "Segarkan"}
              </button>
            </div>

            {notificationLoading ? (
              <p style={{ fontSize: "13px", color: "#777" }}>
                Memuat notifikasi...
              </p>
            ) : (
              <>
                {notificationError && (
                  <p
                    style={{
                      fontSize: "12px",
                      color: "#d97706",
                      margin: "0 0 10px",
                    }}
                  >
                    {notificationError}
                  </p>
                )}

                {notifications.length === 0 ? (
                  <p
                    style={{
                      margin: 0,
                      fontSize: "13px",
                      color: "#777",
                    }}
                  >
                    Belum ada notifikasi saat ini.
                  </p>
                ) : (
                  <div>
                    {notifications.map((item) => (
                      <div
                        key={item.id}
                        style={{
                          padding: "10px 0",
                          borderBottom: "1px solid #eee",
                          display: "flex",
                          gap: "10px",
                          alignItems: "flex-start",
                        }}
                      >
                        <span
                          style={{
                            width: "30px",
                            height: "30px",
                            minWidth: "30px",
                            borderRadius: "50%",
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                            background:
                              item.type === "stock"
                                ? "#fff1f0"
                                : "#eff6ff",
                            color:
                              item.type === "stock"
                                ? "#e74c3c"
                                : "#2563eb",
                            fontSize: "15px",
                          }}
                        >
                          {item.type === "stock" ? "!" : "↓"}
                        </span>

                        <div style={{ minWidth: 0 }}>
                          <strong
                            style={{
                              display: "block",
                              fontSize: "13px",
                              marginBottom: "4px",
                            }}
                          >
                            {item.title}
                          </strong>

                          <p
                            style={{
                              margin: 0,
                              fontSize: "12px",
                              color: "#666",
                              lineHeight: 1.5,
                            }}
                          >
                            {item.description}
                          </p>

                          {item.date && (
                            <span
                              style={{
                                display: "block",
                                marginTop: "4px",
                                fontSize: "11px",
                                color: "#999",
                              }}
                            >
                              {item.date}
                            </span>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </>
            )}
          </div>
        )}
      </div>

      {/* PROFILE */}
      <Link
        href={`/profile?from=${encodeURIComponent(pathname)}`}
        className="profile-button"
      >
        <div className="profile-info">
          <strong>
            {profile.nama || "Memuat profil..."}
          </strong>

          <span>
            {profile.email || ""}
          </span>
        </div>

        <div className="profile-photo-small">
          {profile.foto ? (
            <img
              src={profile.foto}
              alt="Foto Profil"
              style={{
                width: "100%",
                height: "100%",
                objectFit: "cover",
              }}
            />
          ) : (
            <span>
              {profile.nama
                ? profile.nama
                    .split(" ")
                    .filter(Boolean)
                    .slice(0, 2)
                    .map((word) => word[0])
                    .join("")
                    .toUpperCase()
                : "?"}
            </span>
          )}
        </div>
      </Link>
    </div>
  );
}
