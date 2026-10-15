import { NextResponse } from "next/server";
import { SESSION_COOKIE, apiBaseUrl, sessionCookieOptions } from "../../../../lib/server";

export async function POST(req: Request) {
  const body = await req.text();

  const upstream = await fetch(`${apiBaseUrl}/auth/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body,
    cache: "no-store",
  });

  const text = await upstream.text();
  if (!upstream.ok) {
    // Pass the API's message through so the form can show why it failed,
    // without leaking anything about which part was wrong.
    let detail = "Sign-in failed";
    try {
      detail = JSON.parse(text).detail ?? detail;
    } catch {
      /* non-JSON upstream error */
    }
    return NextResponse.json({ error: detail }, { status: upstream.status });
  }

  const session = JSON.parse(text) as {
    token: string;
    expires_in_seconds: number;
    user: unknown;
  };

  // The token stops here: the response carries only who signed in.
  const response = NextResponse.json({ user: session.user });
  response.cookies.set(
    SESSION_COOKIE,
    session.token,
    sessionCookieOptions(session.expires_in_seconds)
  );
  return response;
}
