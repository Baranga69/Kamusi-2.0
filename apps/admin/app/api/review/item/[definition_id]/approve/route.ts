import { NextResponse } from "next/server";

const API_BASE = process.env.KAMUSI_API_BASE_URL!;
const API_KEY = process.env.ADMIN_API_KEY ?? process.env.PROD_ADMIN_API_KEY ?? "";

export async function POST(
    req: Request,
    { params }: { params: { definition_id: string } }
) {
    if (!API_KEY) {
        return NextResponse.json(
            { error: "Missing admin API key", detail: "Set ADMIN_API_KEY or PROD_ADMIN_API_KEY for the admin app." },
            { status: 500 }
        );
    }
    const upstreamUrl = `${API_BASE}/admin/review/item/${params.definition_id}/approve`;
    const body = await req.text();

    const upstream = await fetch(upstreamUrl, {
        method: "POST",
        headers: {
            "x-api-key": API_KEY,
            "content-type": req.headers.get("content-type") ?? "application/json",
        },
        body,
        cache: "no-store",
    });

    const text = await upstream.text();

    if (!upstream.ok) {
        return NextResponse.json(
            { error: "Upstream API error", detail: text },
            { status: upstream.status }
        );
    }

    return new NextResponse(text, {
        status: 200,
        headers: { "content-type": "application/json" },
    });
}
