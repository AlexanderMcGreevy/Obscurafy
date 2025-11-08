import express from "express";
import { analyze } from "../controllers/geminiController.js";

const router = express.Router();

router.get("/health", (req, res) => res.json({ ok: true }));
router.post("/analyze", analyze);

export default router;