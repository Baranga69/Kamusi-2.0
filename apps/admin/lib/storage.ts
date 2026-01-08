"use client";

import { useCallback, useEffect, useState } from "react";

const STORAGE_KEY = "kamusi_admin_api_key";

export const useApiKey = () => {
  const [apiKey, setApiKeyState] = useState<string>("");
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }
    const stored = window.localStorage.getItem(STORAGE_KEY) ?? "";
    setApiKeyState(stored);
    setLoaded(true);
  }, []);

  const setApiKey = useCallback((value: string) => {
    setApiKeyState(value);
    if (typeof window !== "undefined") {
      if (value) {
        window.localStorage.setItem(STORAGE_KEY, value);
      } else {
        window.localStorage.removeItem(STORAGE_KEY);
      }
    }
  }, []);

  return { apiKey, setApiKey, loaded };
};
