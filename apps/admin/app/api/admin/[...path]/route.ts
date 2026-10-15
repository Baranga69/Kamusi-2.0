import { apiBaseUrl, readSessionToken, relay, unauthorized } from "../../../../lib/server";

/**
 * One proxy for every admin call.
 *
 * The browser talks only to this app; the session token is attached here from
 * an httpOnly cookie. That keeps the credential out of page scripts and means
 * the API always knows which account is acting — which is what makes
 * `reviewed_by` on a review decision trustworthy.
 */

const forward = async (req: Request, path: string[], method: string) => {
  const token = readSessionToken();
  if (!token) {
    return unauthorized();
  }

  const url = new URL(req.url);
  const target = `${apiBaseUrl}/admin/${path.map(encodeURIComponent).join("/")}${url.search}`;

  const headers: Record<string, string> = { authorization: `Bearer ${token}` };
  const contentType = req.headers.get("content-type");
  if (contentType) {
    headers["content-type"] = contentType;
  }

  const hasBody = method !== "GET" && method !== "DELETE";
  return relay(
    await fetch(target, {
      method,
      headers,
      body: hasBody ? await req.text() : undefined,
      cache: "no-store",
    })
  );
};

type Context = { params: { path: string[] } };

export const GET = (req: Request, { params }: Context) => forward(req, params.path, "GET");
export const POST = (req: Request, { params }: Context) => forward(req, params.path, "POST");
export const PUT = (req: Request, { params }: Context) => forward(req, params.path, "PUT");
export const PATCH = (req: Request, { params }: Context) => forward(req, params.path, "PATCH");
export const DELETE = (req: Request, { params }: Context) => forward(req, params.path, "DELETE");
