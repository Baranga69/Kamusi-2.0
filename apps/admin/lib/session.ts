"use client";

import { useCallback, useEffect, useState } from "react";

export type Role = "reviewer" | "editor" | "admin";

export interface SessionUser {
  id: string;
  email: string;
  display_name: string;
  role: Role;
  is_active: boolean;
  created_at: string;
  last_login_at?: string | null;
}

const RANK: Record<Role, number> = { reviewer: 0, editor: 1, admin: 2 };

/** True when `user` holds at least `role`. Mirrors ROLE_RANK in app/deps.py. */
export const can = (user: SessionUser | null, role: Role) =>
  user !== null && RANK[user.role] >= RANK[role];

/**
 * Who is signed in.
 *
 * There is no token in the browser to inspect — the session lives in an
 * httpOnly cookie — so the only way to know is to ask the server.
 */
export const useSession = () => {
  const [user, setUser] = useState<SessionUser | null>(null);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    try {
      const response = await fetch("/api/auth/me", { cache: "no-store" });
      setUser(response.ok ? ((await response.json()) as SessionUser) : null);
    } catch {
      setUser(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const signOut = useCallback(async () => {
    await fetch("/api/auth/logout", { method: "POST" });
    setUser(null);
    window.location.href = "/login";
  }, []);

  return { user, loading, refresh, signOut };
};
