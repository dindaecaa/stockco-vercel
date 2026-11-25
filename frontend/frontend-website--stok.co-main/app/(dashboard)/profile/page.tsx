
"use client";

import { useEffect, useRef, useState, type ChangeEvent } from "react";
import Link from "next/link";
import {
  ArrowLeft,
  User,
  Mail,
  Phone,
  Camera,
} from "lucide-react";
import { API_BASE_URL, apiFetch } from "@/lib/api";

type ProfileData = {
  id: number;
  nama: string;
  email: string;
  telepon: string;
  foto: string;
};

type ApiResponse = {
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

const API_ORIGIN = API_BASE_URL.replace(/\/api\/?$/, "");

function getPhotoUrl(photo: string | null | undefined): string {
  if (!photo) return "";

  if (photo.startsWith("http://") || photo.startsWith("https://")) {
    return photo;
  }

  return `${API_ORIGIN}${photo.startsWith("/") ? "" : "/"}${photo}`;
}

function mapProfile(data: NonNullable<ApiResponse["data"]>): ProfileData {
  return {
    id: data.id,
    nama: data.name,
    email: data.email,
    telepon: data.phone ?? "",
    foto: getPhotoUrl(data.profile_photo),
  };
}

export default function ProfilePage() {
  const [profile, setProfile] = useState<ProfileData>({
    id: 0,
    nama: "",
    email: "",
    telepon: "",
    foto: "",
  });

  const [nama, setNama] = useState("");
  const [email, setEmail] = useState("");
  const [telepon, setTelepon] = useState("");

  const [isEditing, setIsEditing] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isUploading, setIsUploading] = useState(false);

  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const fileInputRef = useRef<HTMLInputElement>(null);

  // Mengambil profil langsung dari database melalui backend
  useEffect(() => {
    let isMounted = true;

    const fetchProfile = async () => {
      try {
        setError("");

        const response = await apiFetch("auth/profile");
        const result: ApiResponse = await response.json();

        if (!response.ok || !result.success || !result.data) {
          throw new Error(
            result.message || "Gagal mengambil data profil."
          );
        }

        if (!isMounted) return;

        const profileData = mapProfile(result.data);

        setProfile(profileData);
        setNama(profileData.nama);
        setEmail(profileData.email);
        setTelepon(profileData.telepon);
      } catch (err) {
        if (!isMounted) return;

        setError(
          err instanceof Error
            ? err.message
            : "Terjadi kesalahan saat mengambil profil."
        );
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    };

    fetchProfile();

    return () => {
      isMounted = false;
    };
  }, []);

  // Memberi tahu komponen profil lain bahwa data berubah
  const notifyProfileUpdated = () => {
    window.dispatchEvent(new Event("profilManagerUpdated"));
  };

  // Membuka File Explorer
  const handleChoosePhoto = () => {
    fileInputRef.current?.click();
  };

  // Upload foto ke backend
  const handlePhotoChange = async (
    event: ChangeEvent<HTMLInputElement>
  ) => {
    const file = event.target.files?.[0];

    if (!file) return;

    setError("");
    setSuccess("");

    const allowedTypes = [
      "image/jpeg",
      "image/png",
      "image/webp",
    ];

    if (!allowedTypes.includes(file.type)) {
      setError("Foto harus berformat JPG, PNG, atau WEBP.");
      event.target.value = "";
      return;
    }

    if (file.size > 2 * 1024 * 1024) {
      setError("Ukuran foto maksimal 2 MB.");
      event.target.value = "";
      return;
    }

    try {
      setIsUploading(true);

      const formData = new FormData();
      formData.append("photo", file);

      const response = await apiFetch("auth/profile/photo", {
        method: "POST",
        body: formData,
      });

      const result: ApiResponse = await response.json();

      if (!response.ok || !result.success || !result.data) {
        throw new Error(
          result.message || "Gagal mengunggah foto profil."
        );
      }

      const updatedProfile = mapProfile(result.data);

      setProfile(updatedProfile);
      setSuccess("Foto profil berhasil diperbarui.");

      notifyProfileUpdated();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Terjadi kesalahan saat mengunggah foto."
      );
    } finally {
      setIsUploading(false);
      event.target.value = "";
    }
  };

  // Membuka form edit
  const handleEdit = () => {
    setNama(profile.nama);
    setEmail(profile.email);
    setTelepon(profile.telepon);
    setError("");
    setSuccess("");
    setIsEditing(true);
  };

  // Membatalkan perubahan
  const handleCancel = () => {
    setNama(profile.nama);
    setEmail(profile.email);
    setTelepon(profile.telepon);
    setError("");
    setIsEditing(false);
  };

  // Menyimpan perubahan ke database
  const handleSave = async () => {
    if (!nama.trim() || !email.trim()) {
      setError("Nama dan email wajib diisi.");
      return;
    }

    try {
      setIsSaving(true);
      setError("");
      setSuccess("");

      const response = await apiFetch("auth/profile", {
        method: "PUT",
        body: JSON.stringify({
          name: nama.trim(),
          email: email.trim(),
          phone: telepon.trim() || null,
        }),
      });

      const result: ApiResponse = await response.json();

      if (!response.ok || !result.success || !result.data) {
        throw new Error(
          result.message || "Gagal menyimpan perubahan profil."
        );
      }

      const updatedProfile = mapProfile(result.data);

      setProfile(updatedProfile);
      setNama(updatedProfile.nama);
      setEmail(updatedProfile.email);
      setTelepon(updatedProfile.telepon);

      setIsEditing(false);
      setSuccess("Profil berhasil diperbarui.");

      notifyProfileUpdated();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Terjadi kesalahan saat menyimpan profil."
      );
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoading) {
    return (
      <main className="profile-page">
        <div className="profile-page-header">
          <Link href="/dashboard" className="profile-back">
            <ArrowLeft size={26} strokeWidth={1.6} />
          </Link>
          <h1>Profil</h1>
        </div>

        <section className="profile-content">
          <p>Memuat data profil...</p>
        </section>
      </main>
    );
  }

  return (
    <main className="profile-page">
      {/* HEADER */}
      <div className="profile-page-header">
        <Link href="/dashboard" className="profile-back">
          <ArrowLeft size={26} strokeWidth={1.6} />
        </Link>

        <h1>Profil</h1>
      </div>

      {/* PROFILE CONTENT */}
      <section className="profile-content">
        {/* FOTO PROFIL */}
        <div className="profile-photo-wrapper">
          <div className="profile-main-photo">
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

          {/* TOMBOL KAMERA */}
          <button
            type="button"
            className="profile-camera-button"
            onClick={handleChoosePhoto}
            disabled={isUploading}
            aria-label="Ubah foto profil"
          >
            <Camera size={22} strokeWidth={1.6} />
          </button>

          {/* INPUT FILE */}
          <input
            ref={fileInputRef}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            onChange={handlePhotoChange}
            style={{ display: "none" }}
          />
        </div>

        {isUploading && <p>Mengunggah foto profil...</p>}

        {error && (
          <p role="alert" style={{ color: "red" }}>
            {error}
          </p>
        )}

        {success && (
          <p role="status" style={{ color: "green" }}>
            {success}
          </p>
        )}

        {!isEditing ? (
          <>
            {/* NAMA */}
            <div className="profile-detail">
              <div className="profile-detail-icon">
                <User size={28} strokeWidth={1.5} />
              </div>

              <div>
                <h3>Nama</h3>
                <p>{profile.nama || "-"}</p>
              </div>
            </div>

            {/* EMAIL */}
            <div className="profile-detail">
              <div className="profile-detail-icon">
                <Mail size={28} strokeWidth={1.5} />
              </div>

              <div>
                <h3>Email</h3>
                <p>{profile.email || "-"}</p>
              </div>
            </div>

            {/* NOMOR TELEPON */}
            <div className="profile-detail">
              <div className="profile-detail-icon">
                <Phone size={28} strokeWidth={1.5} />
              </div>

              <div>
                <h3>Nomor Telepon</h3>
                <p>{profile.telepon || "-"}</p>
              </div>
            </div>

            {/* EDIT PROFIL */}
            <button
              type="button"
              className="profile-edit-button"
              onClick={handleEdit}
            >
              Edit Profil
            </button>
          </>
        ) : (
          /* FORM EDIT */
          <div className="profile-edit-form">
            <h2>Edit Profil</h2>

            {/* NAMA */}
            <div className="profile-input-group">
              <label htmlFor="nama">Nama</label>
              <input
                id="nama"
                type="text"
                value={nama}
                onChange={(e) => setNama(e.target.value)}
                maxLength={100}
              />
            </div>

            {/* EMAIL */}
            <div className="profile-input-group">
              <label htmlFor="email">Email</label>
              <input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                maxLength={150}
              />
            </div>

            {/* NOMOR TELEPON */}
            <div className="profile-input-group">
              <label htmlFor="telepon">Nomor Telepon</label>
              <input
                id="telepon"
                type="tel"
                value={telepon}
                onChange={(e) => setTelepon(e.target.value)}
                maxLength={20}
              />
            </div>

            {/* TOMBOL */}
            <div className="profile-edit-actions">
              <button
                type="button"
                className="profile-cancel-button"
                onClick={handleCancel}
                disabled={isSaving}
              >
                Cancel
              </button>

              <button
                type="button"
                className="profile-save-button"
                onClick={handleSave}
                disabled={isSaving}
              >
                {isSaving ? "Menyimpan..." : "Simpan"}
              </button>
            </div>
          </div>
        )}
      </section>
    </main>
  );
}
