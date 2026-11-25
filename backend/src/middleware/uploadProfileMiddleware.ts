
import multer from "multer";
import path from "path";
import fs from "fs";

const uploadDirectory = path.resolve(
  process.cwd(),
  "uploads",
  "profiles"
);

// Pastikan folder penyimpanan tersedia.
fs.mkdirSync(uploadDirectory, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, callback) => {
    callback(null, uploadDirectory);
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
