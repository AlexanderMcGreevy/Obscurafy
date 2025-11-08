import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import apiRouter from "./routes/api.js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json({ limit: "10mb" })); // support image payloads
app.use("/api", apiRouter);

const PORT = process.env.BACKEND_PORT ?? 3000;
app.get("/", (req, res) => res.json({ ok: true }));
app.listen(PORT, () => console.log(`Backend listening on http://localhost:${PORT}`));