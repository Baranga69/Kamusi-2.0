"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { useApiKey } from "../../lib/storage";

export default function LoginPage() {
  const router = useRouter();
  const { apiKey, setApiKey, loaded } = useApiKey();
  const [value, setValue] = useState(apiKey);

  if (!loaded) {
    return <p>Loading...</p>;
  }

  return (
    <section className="card">
      <h1>Admin login</h1>
      <p>Enter the API key provided for admin access. It is stored locally in your browser.</p>
      <label className="field">
        <span>API key</span>
        <input
          type="password"
          value={value}
          onChange={(event) => setValue(event.target.value)}
          placeholder="X-API-Key"
        />
      </label>
      <div className="actions">
        <button
          type="button"
          className="primary"
          onClick={() => {
            setApiKey(value.trim());
            router.push("/lexemes");
          }}
        >
          Save API key
        </button>
        <button
          type="button"
          className="ghost"
          onClick={() => {
            setValue("");
            setApiKey("");
          }}
        >
          Clear
        </button>
      </div>
    </section>
  );
}
