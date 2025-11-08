
import axios from "axios";

const GEMINI_ENDPOINT = process.env.GEMINI_ENDPOINT ?? "https://GENERATIVE_API_ENDPOINT";
const API_KEY = process.env.GEMINI_API_KEY;

export async function analyze(req, res) {
  try {
    if (!API_KEY) {
      return res.status(500).json({ error: "server misconfigured: missing GEMINI_API_KEY" });
    }

    const payload = req.body;
    if (!payload || typeof payload !== "object") {
      return res.status(400).json({ error: "missing or invalid payload" });
    }

    // Forward payload to Gemini (adjust body shape for the exact Gemini API you're using)
    const resp = await axios.post(GEMINI_ENDPOINT, payload, {
      headers: {
        Authorization: `Bearer ${API_KEY}`,
        "Content-Type": "application/json",
      },
      timeout: 30000,
    });

    return res.status(resp.status).json(resp.data);
  } catch (err) {
    console.error("gemini analyze error:", err?.response?.data ?? err.message);
    const status = err?.response?.status ?? 500;
    return res.status(status).json({ error: "backend error", details: err?.response?.data ?? err.message });
  }
}
