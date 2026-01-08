"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import LanguageTabs from "../../components/LanguageTabs";
import {
  createAdminClient,
  workflowStatuses,
  type DefinitionInput,
  type LanguageCode,
  type LexemeInput,
  type SenseInput,
  type Tag,
  type WorkflowStatus,
} from "../../../lib/api";
import { useApiKey } from "../../../lib/storage";

const emptyLexeme: LexemeInput = {
  lemma: "",
  part_of_speech: "",
  status: "draft",
  tags: [],
  senses: [],
};

const newDefinition = (language: LanguageCode): DefinitionInput => ({
  language,
  text: "",
  is_primary: false,
});

const newExample = (language: LanguageCode) => ({
  language,
  text: "",
});

export default function LexemeEditorPage() {
  const params = useParams();
  const router = useRouter();
  const { apiKey, loaded } = useApiKey();
  const [lexeme, setLexeme] = useState<LexemeInput>(emptyLexeme);
  const [activeLang, setActiveLang] = useState<LanguageCode>("sw");
  const [activeExampleLang, setActiveExampleLang] = useState<LanguageCode>("sw");
  const [tags, setTags] = useState<Tag[]>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [validation, setValidation] = useState<string | null>(null);

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);
  const lexemeId = Array.isArray(params?.id) ? params?.id[0] : params?.id;

  useEffect(() => {
    if (!client || !lexemeId || lexemeId === "new") {
      return;
    }
    let cancelled = false;
    const load = async () => {
      try {
        const data = await client.getLexeme(lexemeId);
        if (!cancelled) {
          setLexeme({
            ...data,
            tags: data.tags ?? [],
            senses: data.senses?.map((sense, index) => ({
              ...sense,
              sense_number: sense.sense_number ?? index + 1,
              tags: sense.tags ?? [],
              definitions: sense.definitions ?? [],
              examples: sense.examples ?? [],
            })) ?? [],
          });
        }
      } catch (err) {
        if (!cancelled) {
          setError("Failed to load lexeme.");
        }
      }
    };
    load();
    return () => {
      cancelled = true;
    };
  }, [client, lexemeId]);

  useEffect(() => {
    if (!client) {
      return;
    }
    let cancelled = false;
    client
      .listTags()
      .then((data) => {
        if (!cancelled) {
          setTags(data);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setTags([]);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [client]);

  const updateSense = (index: number, updater: (sense: SenseInput) => SenseInput) => {
    setLexeme((prev) => {
      const senses = [...prev.senses];
      senses[index] = updater(senses[index]);
      return { ...prev, senses };
    });
  };

  const updateDefinitions = (senseIndex: number, definitions: DefinitionInput[]) => {
    updateSense(senseIndex, (sense) => ({ ...sense, definitions }));
  };

  const updateExamples = (senseIndex: number, examples: { language: LanguageCode; text: string }[]) => {
    updateSense(senseIndex, (sense) => ({ ...sense, examples }));
  };

  const handleSave = async () => {
    if (!client) {
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const payload: LexemeInput = {
        ...lexeme,
        senses: lexeme.senses.map((sense, index) => ({
          ...sense,
          sense_number: index + 1,
        })),
      };
      const result = lexemeId && lexemeId !== "new"
        ? await client.updateLexeme(lexemeId, payload)
        : await client.createLexeme(payload);
      setLexeme(result);
      if (lexemeId === "new" && result.id) {
        router.replace(`/lexemes/${result.id}`);
      }
    } catch (err) {
      setError("Failed to save lexeme.");
    } finally {
      setSaving(false);
    }
  };

  const validateForPublish = () => {
    if (!lexeme.part_of_speech.trim()) {
      return "Part of speech is required before publishing.";
    }
    const invalidSense = lexeme.senses.find((sense) =>
      !sense.definitions.some((definition) => definition.language === "sw" && definition.text.trim())
    );
    if (invalidSense) {
      return "Each sense must have at least one Swahili definition before publishing.";
    }
    return null;
  };

  const handlePublish = async () => {
    if (!client) {
      return;
    }
    const issues = validateForPublish();
    setValidation(issues);
    if (issues) {
      return;
    }
    if (!lexemeId || lexemeId === "new") {
      setError("Save the lexeme before publishing.");
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const result = await client.publishLexeme(lexemeId);
      setLexeme(result);
    } catch (err) {
      setError("Failed to publish lexeme.");
    } finally {
      setSaving(false);
    }
  };

  if (!loaded) {
    return <p>Loading...</p>;
  }

  if (!apiKey) {
    return (
      <div className="card">
        <p>
          API key missing. <Link href="/login">Add your API key</Link> to edit lexemes.
        </p>
      </div>
    );
  }

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>{lexemeId === "new" ? "New lexeme" : "Edit lexeme"}</h1>
          <p className="muted">Lemma, POS, senses, tags, and workflow controls.</p>
        </div>
        <div className="actions">
          <button type="button" className="ghost" onClick={() => router.push("/lexemes")}>Back</button>
          <button type="button" className="primary" onClick={handleSave} disabled={saving}>
            {saving ? "Saving..." : "Save"}
          </button>
          <button type="button" className="secondary" onClick={handlePublish} disabled={saving}>
            Publish
          </button>
        </div>
      </div>
      {error && <p className="error">{error}</p>}
      {validation && <p className="error">{validation}</p>}
      <div className="card grid two">
        <label className="field">
          <span>Lemma</span>
          <input value={lexeme.lemma} onChange={(event) => setLexeme({ ...lexeme, lemma: event.target.value })} />
        </label>
        <label className="field">
          <span>Part of speech *</span>
          <input
            value={lexeme.part_of_speech}
            onChange={(event) => setLexeme({ ...lexeme, part_of_speech: event.target.value })}
            placeholder="N, V, Adj..."
          />
        </label>
        <label className="field">
          <span>Status</span>
          <select
            value={lexeme.status}
            onChange={(event) => setLexeme({ ...lexeme, status: event.target.value as WorkflowStatus })}
          >
            {workflowStatuses.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          <span>Lexeme tags</span>
          <div className="tag-list">
            {tags.map((tag) => (
              <label key={tag.id} className="tag-pill">
                <input
                  type="checkbox"
                  checked={lexeme.tags.includes(tag.id)}
                  onChange={(event) => {
                    const next = event.target.checked
                      ? [...lexeme.tags, tag.id]
                      : lexeme.tags.filter((value) => value !== tag.id);
                    setLexeme({ ...lexeme, tags: next });
                  }}
                />
                {tag.name}
              </label>
            ))}
            {tags.length === 0 && <span className="muted">No tags available.</span>}
          </div>
        </label>
      </div>
      <section className="stack">
        <div className="header-row">
          <h2>Senses</h2>
          <button
            type="button"
            className="ghost"
            onClick={() =>
              setLexeme((prev) => ({
                ...prev,
                senses: [
                  ...prev.senses,
                  {
                    sense_number: prev.senses.length + 1,
                    definitions: [],
                    examples: [],
                    tags: [],
                  },
                ],
              }))
            }
          >
            Add sense
          </button>
        </div>
        {lexeme.senses.length === 0 && <p className="muted">No senses yet. Add one to continue.</p>}
        {lexeme.senses.map((sense, index) => (
          <div key={sense.id ?? index} className="card stack">
            <div className="header-row">
              <h3>Sense {index + 1}</h3>
              <div className="actions">
                <button
                  type="button"
                  className="ghost"
                  onClick={() => {
                    if (index === 0) return;
                    setLexeme((prev) => {
                      const senses = [...prev.senses];
                      [senses[index - 1], senses[index]] = [senses[index], senses[index - 1]];
                      return { ...prev, senses };
                    });
                  }}
                >
                  Move up
                </button>
                <button
                  type="button"
                  className="ghost"
                  onClick={() => {
                    if (index === lexeme.senses.length - 1) return;
                    setLexeme((prev) => {
                      const senses = [...prev.senses];
                      [senses[index + 1], senses[index]] = [senses[index], senses[index + 1]];
                      return { ...prev, senses };
                    });
                  }}
                >
                  Move down
                </button>
                <button
                  type="button"
                  className="ghost"
                  onClick={() =>
                    setLexeme((prev) => ({
                      ...prev,
                      senses: prev.senses.filter((_, sIndex) => sIndex !== index),
                    }))
                  }
                >
                  Remove
                </button>
              </div>
            </div>
            <div className="grid two">
              <label className="field">
                <span>Domain</span>
                <input
                  value={sense.domain ?? ""}
                  onChange={(event) => updateSense(index, (prev) => ({ ...prev, domain: event.target.value }))}
                />
              </label>
              <label className="field">
                <span>Register</span>
                <input
                  value={sense.register ?? ""}
                  onChange={(event) => updateSense(index, (prev) => ({ ...prev, register: event.target.value }))}
                />
              </label>
              <label className="field span-2">
                <span>Usage note</span>
                <textarea
                  value={sense.usage_note ?? ""}
                  onChange={(event) => updateSense(index, (prev) => ({ ...prev, usage_note: event.target.value }))}
                />
              </label>
            </div>
            <div className="stack">
              <div className="header-row">
                <h4>Definitions</h4>
                <div className="actions">
                  <LanguageTabs active={activeLang} onChange={setActiveLang} />
                  <button
                    type="button"
                    className="ghost"
                    onClick={() => updateDefinitions(index, [...sense.definitions, newDefinition(activeLang)])}
                  >
                    Add definition
                  </button>
                </div>
              </div>
              {sense.definitions
                .map((definition, defIndex) => ({ definition, defIndex }))
                .filter(({ definition }) => definition.language === activeLang)
                .map(({ definition, defIndex }) => (
                  <div key={definition.id ?? defIndex} className="card nested">
                    <label className="field">
                      <span>{activeLang.toUpperCase()} definition</span>
                      <textarea
                        value={definition.text}
                        onChange={(event) => {
                          const next = [...sense.definitions];
                          next[defIndex] = { ...definition, text: event.target.value };
                          updateDefinitions(index, next);
                        }}
                      />
                    </label>
                    <label className="checkbox">
                      <input
                        type="checkbox"
                        checked={definition.is_primary}
                        onChange={(event) => {
                          const next = sense.definitions.map((item, itemIndex) => {
                            if (item.language !== activeLang) {
                              return item;
                            }
                            if (itemIndex === defIndex) {
                              return { ...item, is_primary: event.target.checked };
                            }
                            return { ...item, is_primary: event.target.checked ? false : item.is_primary };
                          });
                          updateDefinitions(index, next);
                        }}
                      />
                      Primary definition
                    </label>
                    <button
                      type="button"
                      className="ghost"
                      onClick={() => {
                        const next = sense.definitions.filter((_, itemIndex) => itemIndex !== defIndex);
                        updateDefinitions(index, next);
                      }}
                    >
                      Remove definition
                    </button>
                  </div>
                ))}
            </div>
            <div className="stack">
              <div className="header-row">
                <h4>Examples</h4>
                <div className="actions">
                  <LanguageTabs active={activeExampleLang} onChange={setActiveExampleLang} />
                  <button
                    type="button"
                    className="ghost"
                    onClick={() => updateExamples(index, [...sense.examples, newExample(activeExampleLang)])}
                  >
                    Add example
                  </button>
                </div>
              </div>
              {sense.examples
                .map((example, exampleIndex) => ({ example, exampleIndex }))
                .filter(({ example }) => example.language === activeExampleLang)
                .map(({ example, exampleIndex }) => (
                  <div key={example.id ?? exampleIndex} className="card nested">
                    <label className="field">
                      <span>{activeExampleLang.toUpperCase()} example</span>
                      <textarea
                        value={example.text}
                        onChange={(event) => {
                          const next = [...sense.examples];
                          next[exampleIndex] = { ...example, text: event.target.value };
                          updateExamples(index, next);
                        }}
                      />
                    </label>
                    <button
                      type="button"
                      className="ghost"
                      onClick={() => {
                        const next = sense.examples.filter((_, itemIndex) => itemIndex !== exampleIndex);
                        updateExamples(index, next);
                      }}
                    >
                      Remove example
                    </button>
                  </div>
                ))}
            </div>
            <div className="stack">
              <h4>Sense tags</h4>
              <div className="tag-list">
                {tags.map((tag) => (
                  <label key={tag.id} className="tag-pill">
                    <input
                      type="checkbox"
                      checked={sense.tags.includes(tag.id)}
                      onChange={(event) => {
                        const next = event.target.checked
                          ? [...sense.tags, tag.id]
                          : sense.tags.filter((value) => value !== tag.id);
                        updateSense(index, (prev) => ({ ...prev, tags: next }));
                      }}
                    />
                    {tag.name}
                  </label>
                ))}
                {tags.length === 0 && <span className="muted">No tags available.</span>}
              </div>
            </div>
          </div>
        ))}
      </section>
    </section>
  );
}
