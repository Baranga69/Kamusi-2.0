import { describe, expect, it, vi } from "vitest";
import axios from "axios";
import { createAdminClient } from "./api";

vi.mock("axios", () => ({
  default: {
    create: vi.fn(),
  },
}));

const mockedAxios = axios as unknown as { create: ReturnType<typeof vi.fn> };

describe("admin client", () => {
  it("routes calls through the session-attaching proxy", () => {
    mockedAxios.create = vi.fn().mockReturnValue({});
    createAdminClient();
    // No credential here: the /api/admin proxy attaches the session cookie
    // server-side, so nothing in the browser holds a key.
    expect(mockedAxios.create).toHaveBeenCalledWith({ baseURL: "/api/admin" });
  });

  it("calls the review queue with its filters", async () => {
    const get = vi.fn().mockResolvedValue({ data: [] });
    mockedAxios.create = vi.fn().mockReturnValue({ get });

    const client = createAdminClient();
    await client.listReviewQueue({ status: "unreviewed", q: "kula" });

    expect(get).toHaveBeenCalledWith("/review/queue", {
      params: { status: "unreviewed", q: "kula" },
    });
  });

  it("does not send a reviewer name, so the server decides who acted", async () => {
    const post = vi.fn().mockResolvedValue({ data: {} });
    mockedAxios.create = vi.fn().mockReturnValue({ post });

    const client = createAdminClient();
    await client.approveReviewItem("def-1");

    expect(post).toHaveBeenCalledWith("/review/item/def-1/approve", {});
  });
});
