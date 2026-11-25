
import "dotenv/config";
import app from "./app";

const PORT = Number(process.env.PORT || 3001);

if (
  !Number.isInteger(PORT) ||
  PORT < 1 ||
  PORT > 65535
) {
  throw new Error(
    "PORT harus berupa angka antara 1 sampai 65535."
  );
}

app.listen(PORT, "0.0.0.0", () => {
  console.log("=================================");
  console.log("       STOCK.CO BACKEND API      ");
  console.log("=================================");
  console.log(`Server berjalan di http://localhost:${PORT}`);
  console.log("=================================");
});
