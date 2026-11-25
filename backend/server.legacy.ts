
import "dotenv/config";

import express, {
  type NextFunction,
  type Request,
  type Response,
} from "express";
import cors from "cors";
import type { RowDataPacket } from "mysql2";
import pool from "./db";

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

const PORT = Number(process.env.PORT || 3001);

if (!Number.isInteger(PORT) || PORT < 1 || PORT > 65535) {
  throw new Error("PORT harus berupa angka antara 1 sampai 65535.");
}

// ==========================================
// MIDDLEWARE
// ==========================================

app.use(cors());
app.use(express.json({ limit: "1mb" }));

// ==========================================
// HOME
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
// DATABASE TEST
// ==========================================

app.get("/api/db-test", async (_req: Request, res: Response) => {
  try {
    const [rows] = await pool.query<RowDataPacket[]>(
      "SELECT VERSION() AS version, DATABASE() AS database_name"
    );

    res.status(200).json({
      success: true,
      message: "Koneksi database berhasil.",
      data: rows[0] ?? null,
    });
  } catch (err: unknown) {
    console.error("Database test error:", err);

    res.status(500).json({
      success: false,
      message: "Koneksi database gagal.",
    });
  }
});

// ==========================================
// REGISTER ROUTES
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
    _req: Request,
    res: Response,
    _next: NextFunction
  ) => {
    console.error("Global API error:", err);

    if (
      err instanceof SyntaxError &&
      "status" in err &&
      err.status === 400
    ) {
      res.status(400).json({
        success: false,
        message: "Format JSON tidak valid.",
      });
      return;
    }

    res.status(500).json({
      success: false,
      message: "Terjadi kesalahan pada server.",
    });
  }
);

// ==========================================
// START SERVER
// ==========================================

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Stock.co API berjalan di http://localhost:${PORT}`);
});
