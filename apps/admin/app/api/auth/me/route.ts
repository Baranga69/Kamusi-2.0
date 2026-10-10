import { apiBaseUrl, readSessionToken, relay, unauthorized } from "../../../../lib/server";

export async function GET() {
  const token = readSessionToken();
  if (!token) {
    return unauthorized();
  }
  return relay(
    await fetch(`${apiBaseUrl}/auth/me`, {
      headers: { authorization: `Bearer ${token}` },
      cache: "no-store",
    })
  );
}
