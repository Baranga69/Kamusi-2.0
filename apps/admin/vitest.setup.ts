// Registers the jest-dom matchers on vitest's `expect` without relying on
// globals, so test files import `expect`/`test` from "vitest" explicitly.
import "@testing-library/jest-dom/vitest";
import { afterEach } from "vitest";
import { cleanup } from "@testing-library/react";

// Without this each render stacks onto the previous test's DOM, so a second
// test asserting on the same component fails with "found multiple elements".
afterEach(cleanup);
