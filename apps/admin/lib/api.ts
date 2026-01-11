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

export interface Tag {
  id: string;
  name: string;
  description?: string;
}

export interface Source {
  id: string;
  name: string;
  description?: string;
}

export interface License {
  id: string;
  name: string;
  url?: string;
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
  review_status?: string | null;
  is_ai_generated: boolean;
  morphology_like: boolean;
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

export interface ListResponse<T> {
  items: T[];
}

const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

const getItems = <T>(data: ListResponse<T> | T[]): T[] => {
  if (Array.isArray(data)) {
    return data;
  }
  return data.items;
};

export const createAdminClient = (apiKey: string) => {
  const client = axios.create({
    baseURL: apiBaseUrl,
    headers: {
      "X-API-Key": apiKey,
    },
  });

  return {
    async listLexemes(query?: string, status?: WorkflowStatus) {
      const response = await client.get<ListResponse<LexemeInput> | LexemeInput[]>("/admin/lexemes", {
        params: { query, status },
      });
      return getItems(response.data);
    },
    async getLexeme(id: string) {
      const response = await client.get<LexemeInput>(`/admin/lexemes/${id}`);
      return response.data;
    },
    async createLexeme(payload: LexemeInput) {
      const response = await client.post<LexemeInput>("/admin/lexemes", payload);
      return response.data;
    },
    async updateLexeme(id: string, payload: LexemeInput) {
      const response = await client.put<LexemeInput>(`/admin/lexemes/${id}`, payload);
      return response.data;
    },
    async publishLexeme(id: string) {
      const response = await client.post<LexemeInput>(`/admin/lexemes/${id}/publish`);
      return response.data;
    },
    async reviewLexeme(id: string) {
      const response = await client.post<LexemeInput>(`/admin/lexemes/${id}/review`);
      return response.data;
    },
    async listExpressions(query?: string, status?: WorkflowStatus) {
      const response = await client.get<ListResponse<ExpressionInput> | ExpressionInput[]>("/admin/expressions", {
        params: { query, status },
      });
      return getItems(response.data);
    },
    async getExpression(id: string) {
      const response = await client.get<ExpressionInput>(`/admin/expressions/${id}`);
      return response.data;
    },
    async createExpression(payload: ExpressionInput) {
      const response = await client.post<ExpressionInput>("/admin/expressions", payload);
      return response.data;
    },
    async updateExpression(id: string, payload: ExpressionInput) {
      const response = await client.put<ExpressionInput>(`/admin/expressions/${id}`, payload);
      return response.data;
    },
    async publishExpression(id: string) {
      const response = await client.post<ExpressionInput>(`/admin/expressions/${id}/publish`);
      return response.data;
    },
    async listTags() {
      const response = await client.get<ListResponse<Tag> | Tag[]>("/admin/tags");
      return getItems(response.data);
    },
    async createTag(payload: Omit<Tag, "id">) {
      const response = await client.post<Tag>("/admin/tags", payload);
      return response.data;
    },
    async updateTag(id: string, payload: Omit<Tag, "id">) {
      const response = await client.put<Tag>(`/admin/tags/${id}`, payload);
      return response.data;
    },
    async deleteTag(id: string) {
      await client.delete(`/admin/tags/${id}`);
    },
    async listSources() {
      const response = await client.get<ListResponse<Source> | Source[]>("/admin/sources");
      return getItems(response.data);
    },
    async createSource(payload: Omit<Source, "id">) {
      const response = await client.post<Source>("/admin/sources", payload);
      return response.data;
    },
    async updateSource(id: string, payload: Omit<Source, "id">) {
      const response = await client.put<Source>(`/admin/sources/${id}`, payload);
      return response.data;
    },
    async deleteSource(id: string) {
      await client.delete(`/admin/sources/${id}`);
    },
    async listLicenses() {
      const response = await client.get<ListResponse<License> | License[]>("/admin/licenses");
      return getItems(response.data);
    },
    async createLicense(payload: Omit<License, "id">) {
      const response = await client.post<License>("/admin/licenses", payload);
      return response.data;
    },
    async updateLicense(id: string, payload: Omit<License, "id">) {
      const response = await client.put<License>(`/admin/licenses/${id}`, payload);
      return response.data;
    },
    async deleteLicense(id: string) {
      await client.delete(`/admin/licenses/${id}`);
    },
    async listReviewQueue(params?: {
      status?: ReviewStatus;
      q?: string;
      pos_code?: string;
      lexeme_status?: string;
      limit?: number;
      offset?: number;
      sort?: "oldest" | "newest" | "lemma";
    }) {
      const response = await client.get<ReviewQueueItem[]>(\"/admin/review/queue\", { params });
      return response.data;
    },
    async getReviewItem(id: string) {
      const response = await client.get<ReviewDetail>(`/admin/review/item/${id}`);
      return response.data;
    },
    async approveReviewItem(id: string, reviewer: string) {
      const response = await client.post<ReviewActionResponse>(`/admin/review/item/${id}/approve`, {
        reviewer,
      });
      return response.data;
    },
    async editReviewItem(id: string, payload: { reviewer: string; definition: string; gloss?: string | null }) {
      const response = await client.post<ReviewActionResponse>(`/admin/review/item/${id}/edit`, payload);
      return response.data;
    },
    async rejectReviewItem(
      id: string,
      payload: { reviewer: string; reason: string; note?: string | null }
    ) {
      const response = await client.post<ReviewActionResponse>(`/admin/review/item/${id}/reject`, payload);
      return response.data;
    },
    async bulkReview(payload: {
      reviewer: string;
      action: \"approve\" | \"reject\";
      ids: string[];
      reason?: string;
      note?: string | null;
    }) {
      const response = await client.post<ReviewBulkResponse>(\"/admin/review/bulk\", payload);
      return response.data;
    },
  };
};

export const workflowStatuses: WorkflowStatus[] = ["draft", "reviewed", "published", "archived"];
