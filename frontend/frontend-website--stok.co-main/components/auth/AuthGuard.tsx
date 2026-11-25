
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api";

type AuthGuardProps = {
  children: React.ReactNode;
};

export default function AuthGuard({ children }: AuthGuardProps) {
  const router = useRouter();

  const [isChecking, setIsChecking] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");

  useEffect(() => {
    let isMounted = true;

    async function verifySession() {
      const token = localStorage.getItem("stockco_token");

      // Token tidak ada = tidak boleh masuk dashboard
      if (!token) {
        router.replace("/login");
        return;
      }

      try {
        const response = await apiFetch("auth/profile");

        // Token invalid / expired / tidak memiliki akses
        if (response.status === 401 || response.status === 403) {
          localStorage.removeItem("stockco_token");

          if (isMounted) {
            router.replace("/login");
          }

          return;
        }

        if (!response.ok) {
          if (isMounted) {
            setErrorMessage(
              "Gagal memverifikasi sesi. Silakan coba kembali."
            );
            setIsChecking(false);
          }
          return;
        }

        const result = await response.json();

        // Respons profil tidak valid = sesi dianggap tidak valid
        if (!result.success || !result.data) {
          localStorage.removeItem("stockco_token");

          if (isMounted) {
            router.replace("/login");
          }

          return;
        }

        if (isMounted) {
          setIsAuthenticated(true);
          setIsChecking(false);
        }
      } catch {
        if (isMounted) {
          setErrorMessage(
            "Server tidak dapat dihubungi. Periksa koneksi backend."
          );
          setIsChecking(false);
        }
      }
    }

    verifySession();

    return () => {
      isMounted = false;
    };
  }, [router]);

  // Selama pengecekan, jangan render isi dashboard
  if (isChecking) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#f8fafc]">
        <div className="flex flex-col items-center gap-3">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-gray-200 border-t-blue-600" />

          <p className="text-sm text-gray-500">
            Memeriksa sesi login...
          </p>
        </div>
      </div>
    );
  }

  // Jika gagal terhubung ke server, dashboard tetap tidak ditampilkan
  if (errorMessage) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#f8fafc] p-6">
        <div className="max-w-md rounded-2xl bg-white p-6 text-center shadow-sm">
          <h2 className="text-lg font-semibold text-gray-800">
            Verifikasi login gagal
          </h2>

          <p className="mt-2 text-sm text-gray-500">
            {errorMessage}
          </p>

          <button
            type="button"
            onClick={() => window.location.reload()}
            className="mt-5 rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
          >
            Coba Lagi
          </button>

          <button
            type="button"
            onClick={() => {
              localStorage.removeItem("stockco_token");
              router.replace("/login");
            }}
            className="mt-3 block w-full text-sm text-gray-500 hover:text-gray-700"
          >
            Kembali ke Login
          </button>
        </div>
      </div>
    );
  }

  // Jangan render protected content jika belum terautentikasi
  if (!isAuthenticated) {
    return null;
  }

  return <>{children}</>;
}
