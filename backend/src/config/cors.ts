
import cors, { type CorsOptions } from "cors";

const allowedOrigins = (process.env.CORS_ORIGINS || "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

const isProduction = process.env.NODE_ENV === "production";

export const corsOptions: CorsOptions = {
  origin(origin, callback) {
    // Request dari aplikasi mobile atau server tanpa Origin.
    if (!origin) {
      callback(null, true);
      return;
    }

    // Development tanpa daftar origin: izinkan untuk pengembangan lokal.
    if (!isProduction && allowedOrigins.length === 0) {
      callback(null, true);
      return;
    }

    // Production hanya menerima origin yang terdaftar.
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
      return;
    }

    callback(new Error("Origin tidak diizinkan oleh kebijakan CORS."));
  },

  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
  exposedHeaders: [],
  credentials: false,
  optionsSuccessStatus: 204,
};
