import { describe, expect, it, vi } from "vitest";
import axios from "axios";
import { createAdminClient } from "./api";

vi.mock("axios", () => ({
  default: {
    create: vi.fn(),
  },
}));

const mockedAxios = axios as unknown as { create: ReturnType<typeof vi.fn> };

describe("admin review client", () => {
  it("calls review queue endpoint with params", async () => {
    const apiGet = vi.fn().mockResolvedValue({ data: [] });
    const reviewGet = vi.fn().mockResolvedValue({ data: [] });
    mockedAxios.create = vi
      .fn()
      .mockReturnValueOnce({ get: apiGet })
      .mockReturnValueOnce({ get: reviewGet });

    const client = createAdminClient("test-key");
    await client.listReviewQueue({ status: "unreviewed", q: "kula" });

    expect(reviewGet).toHaveBeenCalledWith("/review/queue", { params: { status: "unreviewed", q: "kula" } });
  });
});
