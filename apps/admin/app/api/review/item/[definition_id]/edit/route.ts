import { NextResponse } from "next/server";

const API_BASE = process.env.KAMUSI_API_BASE_URL!;
const API_KEY = process.env.ADMIN_API_KEY!;

export async function POST(
  req: Request,
  { params }: { params: { definition_id: string } }
) {
  const upstreamUrl = `${API_BASE}/admin/review/item/${params.definition_id}/edit`;
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
