/**
 * Does the console send what the API accepts?
 *
 * The other tests here mock axios and assert the client calls what we expect.
 * That proves the client is self-consistent and nothing else — a review
 * action shipped returning 422 for every real caller while those tests stayed
 * green, because the API required a `reviewer` field the console had
 * correctly stopped sending.
 *
 * This validates the bodies the client actually produces against
 * `packages/contracts/openapi.yaml`, which is generated from the running API.
 * CI separately fails if that spec is stale, so the two together mean: the
 * request shapes in this file are checked against the real server contract.
 */
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

import Ajv2020, { type ValidateFunction } from "ajv/dist/2020";
import yaml from "js-yaml";
import axios from "axios";
import { beforeAll, describe, expect, it, vi } from "vitest";

import { createAdminClient } from "./api";

vi.mock("axios", () => ({ default: { create: vi.fn() } }));
const mockedAxios = axios as unknown as { create: ReturnType<typeof vi.fn> };

type OpenApi = {
  paths: Record<string, Record<string, { requestBody?: { content: Record<string, { schema: unknown }> } }>>;
};

const SPEC_PATH = resolve(__dirname, "../../../packages/contracts/openapi.yaml");

let spec: OpenApi;
let ajv: Ajv2020;

beforeAll(() => {
  spec = yaml.load(readFileSync(SPEC_PATH, "utf8")) as OpenApi;
  // strict off: an OpenAPI document carries keywords (`servers`, `tags`,
  // `operationId`) that are not JSON Schema.
  // Shape, not formats: `uuid` and `date-time` are annotations the API uses
  // for documentation, and validating them here would only restate what the
  // TypeScript types already say.
  ajv = new Ajv2020({ strict: false, allErrors: true, validateFormats: false });
  ajv.addSchema(spec as object, "openapi");
});

/** The request-body validator for one operation, straight from the spec. */
const validatorFor = (method: string, path: string): ValidateFunction => {
  const operation = spec.paths?.[path]?.[method];
  if (!operation) {
    throw new Error(`${method.toUpperCase()} ${path} is not in the OpenAPI spec`);
  }
  const schema = operation.requestBody?.content?.["application/json"]?.schema as
    | { $ref?: string }
    | undefined;
  if (!schema) {
    throw new Error(`${method.toUpperCase()} ${path} declares no JSON request body`);
  }
  // FastAPI always names request bodies, so this is a local `$ref`. Point it
  // at the registered document, which also gives nested refs the right base
  // to resolve against.
  if (!schema.$ref?.startsWith("#/")) {
    throw new Error(
      `${method.toUpperCase()} ${path} has an inline request schema; expected a $ref`
    );
  }
  return ajv.compile({ $ref: `openapi${schema.$ref}` });
};

/** Run `call`, returning the request body the client handed to axios. */
const bodySentBy = async (call: (client: ReturnType<typeof createAdminClient>) => Promise<unknown>) => {
  let captured: unknown;
  const record = vi.fn((_url: string, body?: unknown) => {
    captured = body;
    return Promise.resolve({ data: {} });
  });
  mockedAxios.create = vi.fn().mockReturnValue({
    post: record,
    put: record,
    get: vi.fn().mockResolvedValue({ data: [] }),
    delete: vi.fn().mockResolvedValue({ data: {} }),
  });

  await call(createAdminClient());
  return captured;
};

const expectValid = (body: unknown, method: string, path: string) => {
  const validate = validatorFor(method, path);
  const ok = validate(body);
  if (!ok) {
    const problems = (validate.errors ?? [])
      .map((error) => `${error.instancePath || "(root)"} ${error.message}`)
      .join("; ");
    throw new Error(
      `The console sends a body the API would reject.\n` +
        `  ${method.toUpperCase()} ${path}\n` +
        `  sent: ${JSON.stringify(body)}\n` +
        `  problem: ${problems}`
    );
  }
  expect(ok).toBe(true);
};

describe("review actions match the API contract", () => {
  // This is the exact case that shipped broken: an empty body, because the
  // server reads the reviewer from the session.
  it("approve sends a body the API accepts", async () => {
    const body = await bodySentBy((client) => client.approveReviewItem("def-1"));
    expectValid(body, "post", "/admin/review/item/{definition_id}/approve");
  });

  it("edit sends a body the API accepts", async () => {
    const body = await bodySentBy((client) =>
      client.editReviewItem("def-1", { definition: "maelezo mapya", gloss: null })
    );
    expectValid(body, "post", "/admin/review/item/{definition_id}/edit");
  });

  it("edit without a gloss is still accepted", async () => {
    const body = await bodySentBy((client) =>
      client.editReviewItem("def-1", { definition: "maelezo mapya" })
    );
    expectValid(body, "post", "/admin/review/item/{definition_id}/edit");
  });

  it("reject sends a body the API accepts", async () => {
    const body = await bodySentBy((client) =>
      client.rejectReviewItem("def-1", { reason: "si sahihi", note: "imetafsiriwa vibaya" })
    );
    expectValid(body, "post", "/admin/review/item/{definition_id}/reject");
  });

  it("bulk approve sends a body the API accepts", async () => {
    const body = await bodySentBy((client) =>
      client.bulkReview({
        action: "approve",
        ids: ["3f7c1a66-1b2e-4a9e-9a1f-2d6f4c8b0e11"],
      })
    );
    expectValid(body, "post", "/admin/review/bulk");
  });

  it("no review action sends a reviewer name", async () => {
    // Who acted is established by the server from the session. A client that
    // supplies it is either redundant or forging an audit trail.
    const bodies = [
      await bodySentBy((client) => client.approveReviewItem("def-1")),
      await bodySentBy((client) =>
        client.editReviewItem("def-1", { definition: "maelezo" })
      ),
      await bodySentBy((client) => client.rejectReviewItem("def-1", { reason: "si sahihi" })),
      await bodySentBy((client) => client.bulkReview({ action: "approve", ids: [] })),
    ];
    for (const body of bodies) {
      expect(body).not.toHaveProperty("reviewer");
    }
  });
});

describe("content writes match the API contract", () => {
  it("creating a tag sends a body the API accepts", async () => {
    const body = await bodySentBy((client) =>
      client.createTag({
        name: "chakula",
        tag_type_id: "3f7c1a66-1b2e-4a9e-9a1f-2d6f4c8b0e11",
        description: null,
      })
    );
    expectValid(body, "post", "/admin/tags");
  });

  it("creating a source sends a body the API accepts", async () => {
    const body = await bodySentBy((client) =>
      client.createSource({
        title: "English Wiktionary",
        author: null,
        publisher: null,
        year: 2026,
        source_type: "dump",
        license_id: "3f7c1a66-1b2e-4a9e-9a1f-2d6f4c8b0e11",
        url: null,
        notes: null,
      })
    );
    expectValid(body, "post", "/admin/sources");
  });

  it("creating a licence sends a body the API accepts", async () => {
    const body = await bodySentBy((client) =>
      client.createLicense({
        name: "CC BY-SA 4.0",
        summary: null,
        can_display: true,
        can_modify: true,
        can_commercialize: false,
      })
    );
    expectValid(body, "post", "/admin/licenses");
  });

  it("creating an account sends a body the API accepts", async () => {
    const body = await bodySentBy((client) =>
      client.createUser({
        email: "ada@example.com",
        display_name: "Ada",
        password: "a-long-enough-password",
        role: "reviewer",
      })
    );
    expectValid(body, "post", "/admin/users");
  });

  it("changing a role sends a body the API accepts", async () => {
    const body = await bodySentBy((client) =>
      client.updateUser("3f7c1a66-1b2e-4a9e-9a1f-2d6f4c8b0e11", { role: "editor" })
    );
    expectValid(body, "put", "/admin/users/{user_id}");
  });
});

describe("the spec itself", () => {
  it("covers every endpoint these tests reference", () => {
    // A rename on the API side should fail loudly here rather than at runtime.
    const referenced = [
      ["post", "/admin/review/item/{definition_id}/approve"],
      ["post", "/admin/review/item/{definition_id}/edit"],
      ["post", "/admin/review/item/{definition_id}/reject"],
      ["post", "/admin/review/bulk"],
      ["get", "/admin/review/queue"],
      ["get", "/admin/lookups"],
      ["get", "/admin/lexemes"],
      ["post", "/admin/users"],
    ] as const;

    for (const [method, path] of referenced) {
      expect(spec.paths?.[path]?.[method], `${method.toUpperCase()} ${path}`).toBeDefined();
    }
  });
});
