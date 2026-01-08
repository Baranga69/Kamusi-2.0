"use client";

import type { LanguageCode } from "../../lib/api";

interface LanguageTabsProps {
  active: LanguageCode;
  onChange: (language: LanguageCode) => void;
}

export default function LanguageTabs({ active, onChange }: LanguageTabsProps) {
  return (
    <div className="tabs">
      {(["sw", "en"] as LanguageCode[]).map((lang) => (
        <button
          key={lang}
          type="button"
          className={active === lang ? "tab active" : "tab"}
          onClick={() => onChange(lang)}
        >
          {lang.toUpperCase()}
        </button>
      ))}
    </div>
  );
}
