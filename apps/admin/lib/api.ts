import axios from "axios";

export type WorkflowStatus = "draft" | "reviewed" | "published" | "archived";
export type LanguageCode = "sw" | "en";
export type ReviewStatus = "unreviewed" | "approved" | "edited" | "rejected" | "reviewed";

export interface DefinitionInput {
  id?: string;
  language: LanguageCode;
  text: string;
  gloss?: string;
  is_primary: boolean;
  source_id?: string;
}

export interface ExampleInput {
  id?: string;
  language: LanguageCode;
  text: string;
  is_primary?: boolean;
  attested?: boolean;
  source_id?: string;
}

export interface SenseInput {
  id?: string;
  sense_number: number;
  domain?: string;
  register?: string;
  usage_note?: string;
  definitions: DefinitionInput[];
  examples: ExampleInput[];
  tags: string[];
}

export interface LexemeInput {
  id?: string;
  lemma: string;
  normalized_lemma?: string;
  part_of_speech: string;
  pronunciation?: string;
  audio_url?: string;
  variants?: string[];
  default_language?: LanguageCode;
  notes?: string;
  status: WorkflowStatus;
  tags: string[];
  senses: SenseInput[];
}

export interface ExpressionInput {
  id?: string;
  text: string;
  expression_type: string;
  region?: string;
  status: WorkflowStatus;
  meanings: DefinitionInput[];
  examples: ExampleInput[];
  link?: {
    lexeme_id?: string;
    sense_id?: string;
  };
}

// The types below mirror apps/api/app/schemas.py. The API is the source of
// truth for data shapes; keep them in step when a schema changes.

export interface Tag {
  id: string;
  name: string;
  tag_type_id: string;
  description?: string | null;
}

export type TagPayload = Omit<Tag, "id">;

export interface Source {
  id: string;
  title: string;
  author?: string | null;
  publisher?: string | null;
  year?: number | null;
  source_type: string;
  license_id: string;
  url?: string | null;
  notes?: string | null;
}

export type SourcePayload = Omit<Source, "id">;

export interface License {
  id: string;
  name: string;
  summary?: string | null;
  can_display: boolean;
  can_modify: boolean;
  can_commercialize: boolean;
}

export type LicensePayload = Omit<License, "id">;

/** Flat row returned by GET /admin/lexemes. */
export interface LexemeListItem {
  id: string;
  lemma: string;
  normalized_lemma: string;
  pos_id: string;
  pos_code?: string | null;
  status: string;
  workflow: WorkflowStatus;
  default_language_code: LanguageCode;
  sense_count: number;
  sw_definition_count: number;
  created_at: string;
  updated_at: string;
}

/** Flat row returned by GET /admin/expressions. */
export interface ExpressionListItem {
  id: string;
  text: string;
  normalized_text: string;
  expression_type_id: string;
  expression_type_code?: string | null;
  region_id?: string | null;
  workflow: WorkflowStatus;
  meaning_count: number;
  created_at: string;
  updated_at: string;
}

export interface ReviewQueueItem {
  sense_definition_id: string;
  sense_id: string;
  lexeme_id: string;
  lemma: string;
  pos_code: string;
  sw_definition_preview: string;
  en_definition_preview?: string | null;
  created_at: string;
  review_status: "unreviewed" | "approved" | "edited" | "rejected";
  is_ai_generated: boolean;
  morphology_like: boolean;
  /** How sure the model was, 0-1. Null when it was never recorded. */
  ai_confidence?: number | null;
  /**
   * What the ingest quality gate objects to, from the API. Empty for a clean
   * definition. The rules live in the backend (app/core/quality.py) so the
   * importer and this queue cannot disagree about what counts as suspect.
   */
  quality_flags?: string[];
}

export interface ReviewDefinitionReference {
  id: string;
  definition: string;
  gloss?: string | null;
  source_id?: string | null;
}

export interface ReviewSourceInfo {
  id: string;
  title: string;
  author?: string | null;
  year?: number | null;
  source_type: string;
  url?: string | null;
}

export interface ReviewDetail {
  sense_definition_id: string;
  sense_id: string;
  lexeme_id: string;
  lemma: string;
  pos_code: string;
  sw_definition: string;
  sw_gloss?: string | null;
  en_definitions: ReviewDefinitionReference[];
  source?: ReviewSourceInfo | null;
  review_status?: string | null;
  is_ai_generated: boolean;
  created_at: string;
  reviewed_by?: string | null;
  reviewed_at?: string | null;
  review_note?: string | null;
}

export interface ReviewActionResponse {
  sense_definition_id: string;
  review_status: string;
  reviewed_by: string;
  reviewed_at: string;
}

export interface ReviewBulkResponse {
  updated_count: number;
  skipped_count: number;
}

/** Mirrors UserPublic in apps/api/app/schemas.py. */
export interface SessionUserLike {
  id: string;
  email: string;
  display_name: string;
  role: string;
  is_active: boolean;
  created_at: string;
  last_login_at?: string | null;
}

export interface LookupOption {
  id: string;
  code: string;
  label: string;
}

export interface LookupBundle {
  languages: { code: string; name: string }[];
  parts_of_speech: LookupOption[];
  registers: LookupOption[];
  domains: LookupOption[];
  regions: LookupOption[];
  expression_types: LookupOption[];
  tag_types: LookupOption[];
}

export interface ListResponse<T> {
  items: T[];
}

const getItems = <T>(data: ListResponse<T> | T[]): T[] => {
  if (Array.isArray(data)) {
    return data;
  }
  return data.items;
};

/**
 * Client for the admin API.
 *
 * Every call goes through this app's own `/api/admin` proxy, which attaches
 * the session token from an httpOnly cookie. Nothing here carries a
 * credential, and nothing in the browser can read one.
 */
export const createAdminClient = () => {
  const client = axios.create({ baseURL: "/api/admin" });
  const reviewClient = client;

  return {
    async listLexemes(query?: string, status?: WorkflowStatus, posCode?: string) {
      const response = await client.get<ListResponse<LexemeListItem> | LexemeListItem[]>("/lexemes", {
        params: { query, status, pos_code: posCode },
      });
      return getItems(response.data);
    },
    async getLexeme(id: string) {
      const response = await client.get<LexemeInput>(`/lexemes/${id}`);
      return response.data;
    },
    async createLexeme(payload: LexemeInput) {
      const response = await client.post<LexemeInput>("/lexemes", payload);
      return response.data;
    },
    async updateLexeme(id: string, payload: LexemeInput) {
      const response = await client.put<LexemeInput>(`/lexemes/${id}`, payload);
      return response.data;
    },
    async publishLexeme(id: string) {
      const response = await client.post<LexemeInput>(`/lexemes/${id}/publish`);
      return response.data;
    },
    async reviewLexeme(id: string) {
      const response = await client.post<LexemeInput>(`/lexemes/${id}/review`);
      return response.data;
    },
    async listExpressions(query?: string, status?: WorkflowStatus) {
      const response = await client.get<ListResponse<ExpressionListItem> | ExpressionListItem[]>(
        "/expressions",
        { params: { query, status } }
      );
      return getItems(response.data);
    },
    async getExpression(id: string) {
      const response = await client.get<ExpressionInput>(`/expressions/${id}`);
      return response.data;
    },
    async createExpression(payload: ExpressionInput) {
      const response = await client.post<ExpressionInput>("/expressions", payload);
      return response.data;
    },
    async updateExpression(id: string, payload: ExpressionInput) {
      const response = await client.put<ExpressionInput>(`/expressions/${id}`, payload);
      return response.data;
    },
    async publishExpression(id: string) {
      const response = await client.post<ExpressionInput>(`/expressions/${id}/publish`);
      return response.data;
    },
    async listUsers() {
      const response = await client.get<SessionUserLike[]>("/users");
      return response.data;
    },
    async createUser(payload: {
      email: string;
      display_name: string;
      password: string;
      role: string;
    }) {
      const response = await client.post<SessionUserLike>("/users", payload);
      return response.data;
    },
    async updateUser(
      id: string,
      payload: { display_name?: string; role?: string; is_active?: boolean }
    ) {
      const response = await client.put<SessionUserLike>(`/users/${id}`, payload);
      return response.data;
    },
    async resetUserPassword(id: string, newPassword: string) {
      await client.post(`/users/${id}/password`, { new_password: newPassword });
    },
    async getLookups() {
      const response = await client.get<LookupBundle>("/lookups");
      return response.data;
    },
    async listTags(query?: string) {
      const response = await client.get<ListResponse<Tag> | Tag[]>("/tags", {
        params: { query },
      });
      return getItems(response.data);
    },
    async createTag(payload: TagPayload) {
      const response = await client.post<Tag>("/tags", payload);
      return response.data;
    },
    async updateTag(id: string, payload: Partial<TagPayload>) {
      const response = await client.put<Tag>(`/tags/${id}`, payload);
      return response.data;
    },
    async deleteTag(id: string) {
      await client.delete(`/tags/${id}`);
    },
    async listSources(query?: string) {
      const response = await client.get<ListResponse<Source> | Source[]>("/sources", {
        params: { query },
      });
      return getItems(response.data);
    },
    async createSource(payload: SourcePayload) {
      const response = await client.post<Source>("/sources", payload);
      return response.data;
    },
    async updateSource(id: string, payload: Partial<SourcePayload>) {
      const response = await client.put<Source>(`/sources/${id}`, payload);
      return response.data;
    },
    async deleteSource(id: string) {
      await client.delete(`/sources/${id}`);
    },
    async listLicenses() {
      const response = await client.get<ListResponse<License> | License[]>("/licenses");
      return getItems(response.data);
    },
    async createLicense(payload: LicensePayload) {
      const response = await client.post<License>("/licenses", payload);
      return response.data;
    },
    async updateLicense(id: string, payload: Partial<LicensePayload>) {
      const response = await client.put<License>(`/licenses/${id}`, payload);
      return response.data;
    },
    async deleteLicense(id: string) {
      await client.delete(`/licenses/${id}`);
    },
    async listReviewQueue(params?: {
      status?: string;
      q?: string;
      pos_code?: string;
      lexeme_status?: string;
      limit?: number;
      offset?: number;
      sort?: "oldest" | "newest" | "lemma" | "confidence";
    }) {
      const response = await reviewClient.get<ReviewQueueItem[]>("/review/queue", { params });
      return response.data;
    },
    async getReviewItem(id: string) {
      const response = await reviewClient.get<ReviewDetail>(`/review/item/${id}`);
      return response.data;
    },
    // No `reviewer` field on any of these: the API records whoever the
    // session belongs to, so a client cannot choose whose name is logged.
    async approveReviewItem(id: string) {
      return reviewClient.post(`/review/item/${id}/approve`, {});
    },
    async editReviewItem(id: string, payload: { definition: string; gloss?: string | null }) {
      return reviewClient.post(`/review/item/${id}/edit`, payload);
    },
    async rejectReviewItem(id: string, payload: { reason: string; note?: string }) {
      return reviewClient.post(`/review/item/${id}/reject`, payload);
    },
    async bulkReview(payload: {
      action: "approve" | "reject";
      ids: string[];
      reason?: string;
      note?: string | null;
    }) {
      const response = await reviewClient.post<ReviewBulkResponse>("/review/bulk", payload);
      return response.data;
    },
  };
};

export const workflowStatuses: WorkflowStatus[] = ["draft", "reviewed", "published", "archived"];

/** Shared instance; it holds no credential, so one is enough. */
export const adminClient = createAdminClient();
