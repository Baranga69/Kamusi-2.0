import axios from "axios";

export type WorkflowStatus = "draft" | "reviewed" | "published" | "archived";
export type LanguageCode = "sw" | "en";

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
  };
};

export const workflowStatuses: WorkflowStatus[] = ["draft", "reviewed", "published", "archived"];
