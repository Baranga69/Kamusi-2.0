import { NextResponse } from "next/server";

const API_BASE = process.env.KAMUSI_API_BASE_URL!;
const API_KEY = process.env.ADMIN_API_KEY!;

export async function GET(
  _req: Request,
  { params }: { params: { definition_id: string } }
) {
  const upstreamUrl = `${API_BASE}/admin/review/item/${params.definition_id}`;

  const upstream = await fetch(upstreamUrl, {
    headers: { "x-api-key": API_KEY },
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
