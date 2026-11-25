
import multer from "multer";
import path from "node:path";
import fs from "node:fs";

// Vercel hanya menyediakan direktori /tmp yang dapat ditulisi.
// Saat lokal, gunakan folder uploads di project backend.
const uploadRootDirectory = process.env.VERCEL
  ? path.join("/tmp", "stockco-uploads")
  : path.resolve(process.cwd(), "uploads");

export const profileUploadDirectory = path.join(
  uploadRootDirectory,
  "profiles"
);

// Pastikan direktori tersedia sebelum multer menyimpan file.
fs.mkdirSync(profileUploadDirectory, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, callback) => {
    callback(null, profileUploadDirectory);
  },

  filename: (_req, file, callback) => {
    const extension = path.extname(file.originalname).toLowerCase();

    const safeFilename = `profile-${Date.now()}-${Math.round(
      Math.random() * 1_000_000
    )}${extension}`;

    callback(null, safeFilename);
  },
});

const allowedMimeTypes = [
  "image/jpeg",
  "image/png",
  "image/webp",
];

const fileFilter: multer.Options["fileFilter"] = (
  _req,
  file,
  callback
) => {
  if (!allowedMimeTypes.includes(file.mimetype)) {
    callback(
      new Error("Foto profil harus berformat JPG, PNG, atau WEBP.")
    );
    return;
  }

  callback(null, true);
};

export const uploadProfilePhoto = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 2 * 1024 * 1024,
    files: 1,
  },
}).single("photo");
