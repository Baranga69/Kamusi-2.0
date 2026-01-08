"use client";

import Link from "next/link";
import { useApiKey } from "../lib/storage";

export default function HomePage() {
  const { apiKey, loaded } = useApiKey();

  if (!loaded) {
    return <p>Loading...</p>;
  }

  return (
    <section className="stack">
      <h1>Kamusi Admin</h1>
      <p className="muted">Use the navigation above to manage entries, expressions, tags, and sources.</p>
      {!apiKey && (
        <div className="alert">
          <strong>API key required.</strong> <Link href="/login">Add your API key to continue.</Link>
        </div>
      )}
      <div className="grid">
        <Link className="card link-card" href="/lexemes">
          <h2>Lexemes</h2>
          <p>Manage lemmas, senses, definitions, examples, tags, and publish workflow.</p>
        </Link>
        <Link className="card link-card" href="/expressions">
          <h2>Expressions</h2>
          <p>Edit methali, semi, and nahau entries with meanings, examples, and links.</p>
        </Link>
        <Link className="card link-card" href="/tags">
          <h2>Tags</h2>
          <p>Create and maintain tagging vocabulary.</p>
        </Link>
        <Link className="card link-card" href="/sources">
          <h2>Sources</h2>
          <p>Track sources and licenses.</p>
        </Link>
      </div>
    </section>
  );
}
