import type { NextApiRequest, NextApiResponse } from "next";

const API_BASE = process.env.KAMUSI_API_BASE_URL!;
const API_KEY = process.env.ADMIN_API_KEY ?? process.env.PROD_ADMIN_API_KEY ?? "";

export default async function handler(
    req: NextApiRequest,
    res: NextApiResponse
) {
    if (!API_KEY) {
        return res.status(500).json({
            error: "Missing admin API key",
            detail: "Set ADMIN_API_KEY or PROD_ADMIN_API_KEY for the admin app.",
        });
    }
    const params = new URLSearchParams(req.query as Record<string, string>);
    const url = `${API_BASE}/admin/review/queue?${params.toString()}`;

    try {
        const upstream = await fetch(url, {
            headers: {
                "x-api-key": API_KEY,
            },
        });

        const text = await upstream.text();

        if (!upstream.ok) {
            return res.status(upstream.status).json({
                error: "Upstream API error",
                detail: text,
            });
        }

        res.status(200).json(JSON.parse(text));
    } catch (err) {
        res.status(500).json({ error: "Proxy failed", detail: String(err) });
    }
}
