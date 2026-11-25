
import "dotenv/config";
import mysql from "mysql2/promise";

const DB_HOST = process.env.DB_HOST;
const DB_PORT = Number(process.env.DB_PORT || 3306);
const DB_USER = process.env.DB_USER;
const DB_PASSWORD = process.env.DB_PASSWORD;
const DB_NAME = process.env.DB_NAME;
const DB_SSL = process.env.DB_SSL === "true";

if (!DB_HOST || !DB_USER || !DB_NAME) {
  throw new Error(
    "Konfigurasi database tidak lengkap. Periksa DB_HOST, DB_USER, dan DB_NAME."
  );
}

if (
  !Number.isInteger(DB_PORT) ||
  DB_PORT < 1 ||
  DB_PORT > 65535
) {
  throw new Error(
    "DB_PORT harus berupa angka antara 1 sampai 65535."
  );
}

if (!DB_PASSWORD) {
  throw new Error("DB_PASSWORD belum diisi.");
}

const pool = mysql.createPool({
  host: DB_HOST,
  port: DB_PORT,
  user: DB_USER,
  password: DB_PASSWORD,
  database: DB_NAME,

  ssl: DB_SSL
    ? {
        minVersion: "TLSv1.2",
      }
    : undefined,

  waitForConnections: true,
  connectionLimit: 10,
  maxIdle: 10,
  idleTimeout: 60000,
  queueLimit: 50,
  connectTimeout: 10000,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
  charset: "utf8mb4",
});

export default pool;
