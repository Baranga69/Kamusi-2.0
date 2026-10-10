import { cookies } from "next/headers";
import { NextResponse } from "next/server";

/**
 * Server-side helpers for talking to the Kamusi API.
 *
 * The browser never holds a credential. Sign-in exchanges an email and
 * password for a session token, which is stored in an httpOnly cookie on this
 * app's own origin and attached here, server-side, on every forwarded request.
 * Page scripts cannot read it, so an XSS bug cannot exfiltrate it.
 */

export const SESSION_COOKIE = "kamusi_session";

export const apiBaseUrl =
  process.env.KAMUSI_API_BASE_URL ??
  process.env.NEXT_PUBLIC_API_BASE_URL ??
  "http://localhost:8000";

export const readSessionToken = () => cookies().get(SESSION_COOKIE)?.value ?? null;

export const unauthorized = () =>
  NextResponse.json({ error: "Not signed in" }, { status: 401 });

/** Pass an upstream response through, preserving its status and JSON body. */
export const relay = async (upstream: Response) => {
  const body = await upstream.text();
  if (upstream.status === 204 || body.length === 0) {
    return new NextResponse(null, { status: upstream.status });
  }
  return new NextResponse(body, {
    status: upstream.status,
    headers: { "content-type": upstream.headers.get("content-type") ?? "application/json" },
  });
};

export const sessionCookieOptions = (maxAge: number) => ({
  httpOnly: true,
  sameSite: "lax" as const,
  path: "/",
  // Set over plain HTTP in development; required in production.
  secure: process.env.NODE_ENV === "production",
  maxAge,
});
