import "./globals.css";
import type { ReactNode } from "react";

export const metadata = {
  title: "Kamusi Admin",
  description: "Kamusi admin console",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <main className="container">{children}</main>
      </body>
    </html>
  );
}
