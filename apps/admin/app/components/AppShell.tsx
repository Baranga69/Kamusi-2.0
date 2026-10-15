"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { can, useSession, type Role } from "../../lib/session";

const navItems: { href: string; label: string; role: Role }[] = [
  { href: "/review", label: "Review", role: "reviewer" },
  { href: "/lexemes", label: "Lexemes", role: "editor" },
  { href: "/expressions", label: "Expressions", role: "editor" },
  { href: "/tags", label: "Tags", role: "editor" },
  { href: "/sources", label: "Sources", role: "editor" },
  { href: "/licenses", label: "Licenses", role: "admin" },
  { href: "/users", label: "Users", role: "admin" },
];

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { user, loading, signOut } = useSession();

  // Only show what the signed-in role can actually open, so nobody is led to
  // a 403. The API enforces this regardless of what the nav offers.
  const visibleItems = navItems.filter((item) => can(user, item.role));

  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="app-header__title">
          <Link href="/">Kamusi Admin</Link>
        </div>
        <nav className="app-header__nav">
          {visibleItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={pathname.startsWith(item.href) ? "active" : ""}
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="app-header__meta">
          {loading ? null : user ? (
            <>
              <span className="muted">
                {user.display_name} · {user.role}
              </span>
              <button type="button" className="ghost" onClick={signOut}>
                Sign out
              </button>
            </>
          ) : (
            <Link href="/login">Sign in</Link>
          )}
        </div>
      </header>
      <main className="app-content">{children}</main>
    </div>
  );
}
