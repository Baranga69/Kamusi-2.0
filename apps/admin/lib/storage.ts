"use client";

import { useCallback, useEffect, useState } from "react";

const STORAGE_KEY = "kamusi_admin_api_key";
const REVIEWER_KEY = "kamusi_admin_reviewer";

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

export const useReviewerName = () => {
  const [reviewer, setReviewerState] = useState<string>("");
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }
    const stored = window.localStorage.getItem(REVIEWER_KEY) ?? "";
    setReviewerState(stored);
    setLoaded(true);
  }, []);

  const setReviewer = useCallback((value: string) => {
    setReviewerState(value);
    if (typeof window !== "undefined") {
      if (value) {
        window.localStorage.setItem(REVIEWER_KEY, value);
      } else {
        window.localStorage.removeItem(REVIEWER_KEY);
      }
    }
  }, []);

  return { reviewer, setReviewer, loaded };
};
