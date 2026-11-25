
import express, {
  type NextFunction,
  type Request,
  type Response,
} from "express";

import path from "node:path";
import cors from "cors";
import { corsOptions } from "./config/cors";

import { logger } from "./utils/logger";
import { requestLoggerMiddleware } from "./middleware/requestLoggerMiddleware";

import authRoutes from "./routes/authRoutes";
import productRoutes from "./routes/productRoutes";
import categoryRoutes from "./routes/categoryRoutes";
import stockMovementRoutes from "./routes/stockMovementRoutes";
import dashboardRoutes from "./routes/dashboardRoutes";
import supplierRoutes from "./routes/supplierRoutes";
import damagedItemRoutes from "./routes/damagedItemRoutes";
import aiStockRoutes from "./routes/aiStockRoutes";
import branchRoutes from "./routes/branchRoutes";
import teamRoutes from "./routes/teamRoutes";

const app = express();

// ==========================================
// GLOBAL MIDDLEWARE
// ==========================================

app.use(requestLoggerMiddleware);

app.use(cors(corsOptions));
app.use(express.json({ limit: "1mb" }));
app.use(express.urlencoded({ extended: true, limit: "1mb" }));

// ==========================================
// STATIC UPLOADS
// ==========================================

// Harus sama dengan direktori yang digunakan multer.
const uploadDirectory = process.env.VERCEL
  ? path.join("/tmp", "stockco-uploads")
  : path.resolve(process.cwd(), "uploads");

app.use("/uploads", express.static(uploadDirectory));

// ==========================================
// ROOT
// ==========================================

app.get("/", (_req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    message: "Stock.co API berjalan!",
  });
});

// ==========================================
// HEALTH CHECK
// ==========================================

app.get("/api/health", (_req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    message: "API sehat dan berjalan.",
  });
});

// ==========================================
// API ROUTES
// ==========================================

app.use("/api/auth", authRoutes);
app.use("/api/products", productRoutes);
app.use("/api/categories", categoryRoutes);
app.use("/api/stock-movements", stockMovementRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/suppliers", supplierRoutes);
app.use("/api/damaged-items", damagedItemRoutes);
app.use("/api/branches", branchRoutes);
app.use("/api/team", teamRoutes);
app.use("/api/ai-stock", aiStockRoutes);

// ==========================================
// NOT FOUND
// ==========================================

app.use((_req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    message: "Endpoint API tidak ditemukan.",
  });
});

// ==========================================
// GLOBAL ERROR HANDLER
// ==========================================

app.use(
  (
    err: unknown,
    req: Request,
    res: Response,
    _next: NextFunction
  ) => {
    const error = err as {
      status?: unknown;
      type?: unknown;
    };

    logger.error("Global API error", {
      requestId: req.requestId ?? "unknown",
      method: req.method,
      path: req.originalUrl,
      errorName: err instanceof Error ? err.name : "UnknownError",
      errorMessage:
        err instanceof Error
          ? err.message
          : "Unknown server error",
    });

    if (
      err instanceof SyntaxError &&
      (error.type === "entity.parse.failed" || error.status === 400)
    ) {
      res.status(400).json({
        success: false,
        message: "Format JSON tidak valid.",
      });
      return;
    }

    if (
      err instanceof Error &&
      err.message.includes("Origin tidak diizinkan")
    ) {
      res.status(403).json({
        success: false,
        message: "Origin tidak diizinkan.",
      });
      return;
    }

    const status =
      typeof error.status === "number" &&
      error.status >= 400 &&
      error.status < 500
        ? error.status
        : 500;

    res.status(status).json({
      success: false,
      message:
        status === 500
          ? "Terjadi kesalahan pada server."
          : "Permintaan tidak dapat diproses.",
    });
  }
);

export default app;
