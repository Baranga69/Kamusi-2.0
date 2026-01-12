"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useApiKey } from "../../lib/storage";

const navItems = [
  { href: "/review", label: "Review" },
  { href: "/lexemes", label: "Lexemes" },
  { href: "/expressions", label: "Expressions" },
  { href: "/tags", label: "Tags" },
  { href: "/sources", label: "Sources" },
  { href: "/licenses", label: "Licenses" },
];

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { apiKey } = useApiKey();

  return (
    <div className="app-shell">
      <header className="app-header">
        <div className="app-header__title">
          <Link href="/">Kamusi Admin</Link>
        </div>
        <nav className="app-header__nav">
          {navItems.map((item) => (
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
          <Link href="/login">{apiKey ? "Update API key" : "Login"}</Link>
        </div>
      </header>
      <main className="app-content">{children}</main>
    </div>
  );
}
