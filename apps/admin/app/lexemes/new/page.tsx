"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  createAdminClient,
  type DefinitionInput,
  type ExampleInput,
  type LanguageCode,
  type LexemeInput,
  type SenseInput,
  type Tag,
  type License,
  type Source,
} from "../../../lib/api";
import { useApiKey } from "../../../lib/storage";

const steps = ["Headword", "Senses", "Tags & metadata", "Review & publish"] as const;

type StepKey = (typeof steps)[number];

type ReadinessCheck = {
  id: string;
  label: string;
  passed: boolean;
  level: "mandatory" | "recommended";
  targetId?: string;
};

const emptyLexeme: LexemeInput = {
  lemma: "",
  part_of_speech: "",
  status: "draft",
  tags: [],
  senses: [],
  variants: [],
  default_language: "sw",
};

const newDefinition = (language: LanguageCode): DefinitionInput => ({
  language,
  text: "",
  gloss: "",
  is_primary: false,
});

const newExample = (language: LanguageCode, sourceId?: string): ExampleInput => ({
  language,
  text: "",
  is_primary: false,
  attested: false,
  source_id: sourceId,
});

const normalizeCheck = (lemma: string) => /[\p{L}\p{N}]/u.test(lemma);

export default function LexemeWizardPage() {
  const router = useRouter();
  const { apiKey, loaded } = useApiKey();
  const [activeStep, setActiveStep] = useState<StepKey>(steps[0]);
  const [lexeme, setLexeme] = useState<LexemeInput>(emptyLexeme);
  const [tags, setTags] = useState<Tag[]>([]);
  const [sources, setSources] = useState<Source[]>([]);
  const [licenses, setLicenses] = useState<License[]>([]);
  const [saving, setSaving] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [reviewing, setReviewing] = useState(false);
  const [archiving, setArchiving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [dirty, setDirty] = useState(false);
  const [stepError, setStepError] = useState<string | null>(null);
  const autosaveTimer = useRef<number | null>(null);
  const dragIndex = useRef<number | null>(null);

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);

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
    client
      .listSources()
      .then((data) => {
        if (!cancelled) {
          setSources(data);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setSources([]);
        }
      });
    client
      .listLicenses()
      .then((data) => {
        if (!cancelled) {
          setLicenses(data);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setLicenses([]);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [client]);

  useEffect(() => {
    if (!dirty) {
      return;
    }
    const handler = (event: BeforeUnloadEvent) => {
      event.preventDefault();
      event.returnValue = "";
    };
    window.addEventListener("beforeunload", handler);
    return () => window.removeEventListener("beforeunload", handler);
  }, [dirty]);

  useEffect(() => {
    if (!toast) {
      return;
    }
    const timer = window.setTimeout(() => setToast(null), 3200);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const validateStep = useCallback(() => {
    if (activeStep === "Headword") {
      if (lexeme.lemma.trim().length < 2) {
        return "Lemma must be at least 2 characters.";
      }
      if (!lexeme.part_of_speech.trim()) {
        return "Part of speech is required.";
      }
    }
    if (activeStep === "Senses" && lexeme.senses.length === 0) {
      return "Add at least one sense to continue.";
    }
    return null;
  }, [activeStep, lexeme]);

  useEffect(() => {
    const handler = (event: KeyboardEvent) => {
      const isSave = (event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "s";
      const isAddSense = (event.metaKey || event.ctrlKey) && event.key === "Enter";
      if (isSave) {
        event.preventDefault();
        void handleSaveDraft();
      }
      if (isAddSense && activeStep === "Senses") {
        event.preventDefault();
        addSense();
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [activeStep, lexeme]);

  useEffect(() => {
    if (!stepError) {
      return;
    }
    const nextError = validateStep();
    if (!nextError) {
      setStepError(null);
    }
  }, [lexeme, activeStep, stepError, validateStep]);

  const markDirty = () => setDirty(true);

  const scheduleAutosave = useCallback(() => {
    if (!dirty) {
      return;
    }
    if (autosaveTimer.current) {
      window.clearTimeout(autosaveTimer.current);
    }
    autosaveTimer.current = window.setTimeout(() => {
      void handleSaveDraft(true);
    }, 700);
  }, [dirty, lexeme]);

  const handleFieldBlur = () => {
    scheduleAutosave();
  };

  const updateSense = (index: number, updater: (sense: SenseInput) => SenseInput) => {
    setLexeme((prev) => {
      const senses = [...prev.senses];
      senses[index] = updater(senses[index]);
      return { ...prev, senses };
    });
    markDirty();
  };

  const updateDefinitions = (senseIndex: number, definitions: DefinitionInput[]) => {
    updateSense(senseIndex, (sense) => ({ ...sense, definitions }));
  };

  const updateExamples = (senseIndex: number, examples: ExampleInput[]) => {
    updateSense(senseIndex, (sense) => ({ ...sense, examples }));
  };

  const addSense = () => {
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
    }));
    markDirty();
  };

  const reorderSense = (fromIndex: number, toIndex: number) => {
    setLexeme((prev) => {
      const senses = [...prev.senses];
      const [moved] = senses.splice(fromIndex, 1);
      senses.splice(toIndex, 0, moved);
      return { ...prev, senses };
    });
    markDirty();
  };

  const handleSaveDraft = useCallback(
    async (quiet = false) => {
      if (!client || saving) {
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
        const result = lexeme.id ? await client.updateLexeme(lexeme.id, payload) : await client.createLexeme(payload);
        setLexeme((prev) => ({ ...prev, ...result }));
        setDirty(false);
        if (!quiet) {
          setToast("Draft saved.");
        }
      } catch (err) {
        setError("Failed to save draft. Your changes are still here.");
      } finally {
        setSaving(false);
      }
    },
    [client, lexeme, saving]
  );

  const handleReview = async () => {
    if (!client || !lexeme.id) {
      return;
    }
    setReviewing(true);
    setError(null);
    try {
      const result = await client.reviewLexeme(lexeme.id);
      setLexeme((prev) => ({ ...prev, ...result }));
      setToast("Lexeme marked as reviewed.");
    } catch (err) {
      setError("Failed to mark as reviewed.");
    } finally {
      setReviewing(false);
    }
  };

  const handleArchive = async () => {
    if (!client || !lexeme.id) {
      return;
    }
    setArchiving(true);
    setError(null);
    try {
      const result = await client.updateLexeme(lexeme.id, { ...lexeme, status: "archived" });
      setLexeme((prev) => ({ ...prev, ...result }));
      setToast("Lexeme archived.");
    } catch (err) {
      setError("Failed to archive lexeme.");
    } finally {
      setArchiving(false);
    }
  };

  const handlePublish = async () => {
    if (!client || !lexeme.id) {
      setError("Save the lexeme before publishing.");
      return;
    }
    setPublishing(true);
    setError(null);
    try {
      const result = await client.publishLexeme(lexeme.id);
      const refreshed = await client.getLexeme(result.id ?? lexeme.id);
      setLexeme((prev) => ({ ...prev, ...refreshed }));
      setToast("Lexeme published. Search entry updated.");
    } catch (err) {
      setError("Failed to publish lexeme.");
    } finally {
      setPublishing(false);
    }
  };

  const handleDuplicate = async () => {
    if (!client) {
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const payload: LexemeInput = {
        ...lexeme,
        id: undefined,
        status: "draft",
        senses: lexeme.senses.map((sense, index) => ({
          ...sense,
          id: undefined,
          sense_number: index + 1,
          definitions: sense.definitions.map((definition) => ({ ...definition, id: undefined })),
          examples: sense.examples.map((example) => ({ ...example, id: undefined })),
        })),
      };
      const result = await client.createLexeme(payload);
      setLexeme((prev) => ({ ...prev, ...result }));
      setDirty(false);
      setToast("Draft duplicated. You are editing the copy.");
    } catch (err) {
      setError("Failed to duplicate lexeme.");
    } finally {
      setSaving(false);
    }
  };

  const readinessChecks = useMemo<ReadinessCheck[]>(() => {
    const checks: ReadinessCheck[] = [];
    const lemmaTrimmed = lexeme.lemma.trim();
    checks.push({
      id: "lemma",
      label: "Lemma is at least 2 characters",
      passed: lemmaTrimmed.length >= 2,
      level: "mandatory",
      targetId: "field-lemma",
    });
    checks.push({
      id: "pos",
      label: "Part of speech is selected",
      passed: lexeme.part_of_speech.trim().length > 0,
      level: "mandatory",
      targetId: "field-pos",
    });
    checks.push({
      id: "senses",
      label: "At least one sense exists",
      passed: lexeme.senses.length > 0,
      level: "mandatory",
      targetId: "section-senses",
    });
    const emptyDefinitionIndex = lexeme.senses.findIndex((sense) =>
      sense.definitions.some((definition) => !definition.text.trim())
    );
    checks.push({
      id: "definition-empty",
      label: "No empty definitions",
      passed: emptyDefinitionIndex === -1,
      level: "mandatory",
      targetId: emptyDefinitionIndex === -1 ? undefined : `sense-${emptyDefinitionIndex}-definitions`,
    });
    const missingSwIndex = lexeme.senses.findIndex(
      (sense) => !sense.definitions.some((definition) => definition.language === "sw" && definition.text.trim())
    );
    checks.push({
      id: "sw-definition",
      label: "Every sense has a Swahili definition",
      passed: missingSwIndex === -1,
      level: "mandatory",
      targetId: missingSwIndex === -1 ? undefined : `sense-${missingSwIndex}-definitions`,
    });
    checks.push({
      id: "normalized",
      label: "Lemma is valid for normalization",
      passed: Boolean(lexeme.normalized_lemma?.trim()) || normalizeCheck(lemmaTrimmed),
      level: "mandatory",
      targetId: "field-lemma",
    });
    checks.push({
      id: "reviewed",
      label: "Lexeme is reviewed before publish",
      passed: lexeme.status === "reviewed" || lexeme.status === "published",
      level: "mandatory",
      targetId: "review-actions",
    });
    const hasExample = lexeme.senses.some((sense) => sense.examples.some((example) => example.text.trim()));
    checks.push({
      id: "example",
      label: "At least one example exists",
      passed: hasExample,
      level: "recommended",
      targetId: "section-examples",
    });
    const attestedMissingSourceIndex = lexeme.senses.findIndex((sense) =>
      sense.examples.some((example) => example.attested && !example.source_id)
    );
    checks.push({
      id: "attested-source",
      label: "Attested examples have a source",
      passed: attestedMissingSourceIndex === -1,
      level: "recommended",
      targetId: attestedMissingSourceIndex === -1 ? undefined : `sense-${attestedMissingSourceIndex}-examples`,
    });
    const hasGloss = lexeme.senses.some((sense) =>
      sense.definitions.some((definition) => definition.gloss && definition.gloss.trim())
    );
    checks.push({
      id: "gloss",
      label: "At least one gloss/summary exists",
      passed: hasGloss,
      level: "recommended",
      targetId: "section-senses",
    });
    return checks;
  }, [lexeme]);

  const mandatoryChecksPassed = readinessChecks.filter((check) => check.level === "mandatory").every((check) => check.passed);
  const canPublish = mandatoryChecksPassed && lexeme.status === "reviewed" && !publishing;

  const scrollToTarget = (targetId?: string) => {
    if (!targetId) {
      return;
    }
    const element = document.getElementById(targetId);
    if (element) {
      element.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  };

  const confirmNavigation = () => {
    if (!dirty) {
      return true;
    }
    return window.confirm("You have unsaved changes. Leave without saving?");
  };

  if (!loaded) {
    return <p>Loading...</p>;
  }

  if (!apiKey) {
    return (
      <div className="card">
        <p>
          API key missing. <Link href="/login">Add your API key</Link> to create lexemes.
        </p>
      </div>
    );
  }

  return (
    <section className="wizard">
      <div className="wizard__header">
        <div>
          <h1>Lexeme creation studio</h1>
          <p className="muted">Move through the guided steps to build and publish a new lexeme.</p>
        </div>
        <div className="actions">
          <button
            type="button"
            className="ghost"
            onClick={() => {
              if (confirmNavigation()) {
                router.push("/lexemes");
              }
            }}
          >
            Back to list
          </button>
          <button type="button" className="primary" onClick={() => void handleSaveDraft()} disabled={saving}>
            {saving ? "Saving..." : "Save draft"}
          </button>
        </div>
      </div>

      <div className="wizard__steps">
        {steps.map((step) => (
          <button
            key={step}
            type="button"
            className={activeStep === step ? "wizard__step active" : "wizard__step"}
            onClick={() => setActiveStep(step)}
          >
            {step}
          </button>
        ))}
      </div>

      {toast && <div className="alert">{toast}</div>}
      {stepError && <p className="error">{stepError}</p>}
      {error && <p className="error">{error}</p>}

      <div className={activeStep === "Headword" ? "wizard__content" : "wizard__content with-panel"}>
        <div className="wizard__main">
          {activeStep === "Headword" && (
            <div className="stack">
              <div className="card grid two">
                <label className="field span-2" id="field-lemma">
                  <span>Lemma *</span>
                  <input
                    value={lexeme.lemma}
                    onChange={(event) => {
                      setLexeme({ ...lexeme, lemma: event.target.value });
                      markDirty();
                    }}
                    onBlur={handleFieldBlur}
                    placeholder="Ingiza kichwa cha neno"
                  />
                  {lexeme.lemma.trim().length > 0 && lexeme.lemma.trim().length < 2 && (
                    <span className="field-error">Lemma must be at least 2 characters.</span>
                  )}
                </label>
                <label className="field" id="field-pos">
                  <span>Part of speech *</span>
                  <input
                    value={lexeme.part_of_speech}
                    onChange={(event) => {
                      setLexeme({ ...lexeme, part_of_speech: event.target.value });
                      markDirty();
                    }}
                    onBlur={handleFieldBlur}
                    placeholder="N, V, Adj..."
                  />
                  {!lexeme.part_of_speech.trim() && <span className="field-error">Part of speech is required.</span>}
                </label>
                <label className="field">
                  <span>Default language</span>
                  <select value="sw" disabled>
                    <option value="sw">Swahili</option>
                  </select>
                </label>
                <label className="field">
                  <span>Pronunciation (IPA)</span>
                  <input
                    value={lexeme.pronunciation ?? ""}
                    onChange={(event) => {
                      setLexeme({ ...lexeme, pronunciation: event.target.value });
                      markDirty();
                    }}
                    onBlur={handleFieldBlur}
                    placeholder="/ˈswa.hi.li/"
                  />
                </label>
                <label className="field">
                  <span>Audio URL</span>
                  <input
                    value={lexeme.audio_url ?? ""}
                    onChange={(event) => {
                      setLexeme({ ...lexeme, audio_url: event.target.value });
                      markDirty();
                    }}
                    onBlur={handleFieldBlur}
                    placeholder="https://..."
                  />
                </label>
                <div className="field span-2">
                  <span>Variants</span>
                  <div className="stack">
                    {(lexeme.variants ?? []).map((variant, index) => (
                      <div key={`${variant}-${index}`} className="variant-row">
                        <input
                          value={variant}
                          onChange={(event) => {
                            const next = [...(lexeme.variants ?? [])];
                            next[index] = event.target.value;
                            setLexeme({ ...lexeme, variants: next });
                            markDirty();
                          }}
                          onBlur={handleFieldBlur}
                          placeholder="Alternative form"
                        />
                        <button
                          type="button"
                          className="ghost"
                          onClick={() => {
                            const next = (lexeme.variants ?? []).filter((_, vIndex) => vIndex !== index);
                            setLexeme({ ...lexeme, variants: next });
                            markDirty();
                          }}
                        >
                          Remove
                        </button>
                      </div>
                    ))}
                    <button
                      type="button"
                      className="ghost"
                      onClick={() => {
                        setLexeme({ ...lexeme, variants: [...(lexeme.variants ?? []), ""] });
                        markDirty();
                      }}
                    >
                      Add variant
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeStep === "Senses" && (
            <div className="stack" id="section-senses">
              <div className="header-row">
                <div>
                  <h2>Senses</h2>
                  <p className="muted">Add ordered senses, definitions, and examples. Ctrl/⌘ + Enter adds a sense.</p>
                </div>
                <button type="button" className="primary" onClick={addSense}>
                  Add sense
                </button>
              </div>
              {lexeme.senses.length === 0 && <p className="muted">No senses yet. Add one to continue.</p>}
              {lexeme.senses.map((sense, index) => (
                <div
                  key={sense.id ?? index}
                  className="card stack draggable-card"
                  draggable
                  onDragStart={(event) => {
                    dragIndex.current = index;
                    event.dataTransfer.effectAllowed = "move";
                  }}
                  onDragOver={(event) => {
                    event.preventDefault();
                    event.dataTransfer.dropEffect = "move";
                  }}
                  onDrop={() => {
                    if (dragIndex.current === null || dragIndex.current === index) {
                      dragIndex.current = null;
                      return;
                    }
                    reorderSense(dragIndex.current, index);
                    dragIndex.current = null;
                  }}
                >
                  <div className="header-row">
                    <div className="sense-title">
                      <span className="drag-handle" aria-hidden>
                        ⠿
                      </span>
                      <h3>Sense {index + 1}</h3>
                    </div>
                    <div className="actions">
                      <button
                        type="button"
                        className="ghost"
                        onClick={() => {
                          if (index === 0) return;
                          reorderSense(index, index - 1);
                        }}
                      >
                        Move up
                      </button>
                      <button
                        type="button"
                        className="ghost"
                        onClick={() => {
                          if (index === lexeme.senses.length - 1) return;
                          reorderSense(index, index + 1);
                        }}
                      >
                        Move down
                      </button>
                      <button
                        type="button"
                        className="ghost"
                        onClick={() => {
                          setLexeme((prev) => ({
                            ...prev,
                            senses: prev.senses.filter((_, sIndex) => sIndex !== index),
                          }));
                          markDirty();
                        }}
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
                        onBlur={handleFieldBlur}
                      />
                    </label>
                    <label className="field">
                      <span>Register</span>
                      <input
                        value={sense.register ?? ""}
                        onChange={(event) => updateSense(index, (prev) => ({ ...prev, register: event.target.value }))}
                        onBlur={handleFieldBlur}
                      />
                    </label>
                    <label className="field span-2">
                      <span>Usage note</span>
                      <textarea
                        value={sense.usage_note ?? ""}
                        onChange={(event) => updateSense(index, (prev) => ({ ...prev, usage_note: event.target.value }))}
                        onBlur={handleFieldBlur}
                      />
                    </label>
                  </div>
                  <div className="stack" id={`sense-${index}-definitions`}>
                    <div className="header-row">
                      <h4>Definitions</h4>
                      <div className="actions">
                        <button
                          type="button"
                          className="ghost"
                          onClick={() => updateDefinitions(index, [...sense.definitions, newDefinition("sw")])}
                        >
                          Add Swahili definition
                        </button>
                        <button
                          type="button"
                          className="ghost"
                          onClick={() => updateDefinitions(index, [...sense.definitions, newDefinition("en")])}
                        >
                          Add definition in another language
                        </button>
                      </div>
                    </div>
                    <div className="definition-group">
                      <h5>Swahili definitions</h5>
                      {sense.definitions.filter((definition) => definition.language === "sw").length === 0 && (
                        <p className="muted">No Swahili definitions yet.</p>
                      )}
                      {sense.definitions
                        .map((definition, defIndex) => ({ definition, defIndex }))
                        .filter(({ definition }) => definition.language === "sw")
                        .map(({ definition, defIndex }) => (
                          <div key={definition.id ?? defIndex} className="card nested">
                            <label className="field">
                              <span>Swahili definition</span>
                              <textarea
                                value={definition.text}
                                onChange={(event) => {
                                  const next = [...sense.definitions];
                                  next[defIndex] = { ...definition, text: event.target.value };
                                  updateDefinitions(index, next);
                                  markDirty();
                                }}
                                onBlur={handleFieldBlur}
                              />
                            </label>
                            <label className="field">
                              <span>Gloss (optional)</span>
                              <input
                                value={definition.gloss ?? ""}
                                onChange={(event) => {
                                  const next = [...sense.definitions];
                                  next[defIndex] = { ...definition, gloss: event.target.value };
                                  updateDefinitions(index, next);
                                  markDirty();
                                }}
                                onBlur={handleFieldBlur}
                                placeholder="Short summary"
                              />
                            </label>
                            <label className="checkbox">
                              <input
                                type="checkbox"
                                checked={definition.is_primary}
                                onChange={(event) => {
                                  const next = sense.definitions.map((item, itemIndex) => {
                                    if (item.language !== "sw") {
                                      return item;
                                    }
                                    if (itemIndex === defIndex) {
                                      return { ...item, is_primary: event.target.checked };
                                    }
                                    return { ...item, is_primary: event.target.checked ? false : item.is_primary };
                                  });
                                  updateDefinitions(index, next);
                                  markDirty();
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
                                markDirty();
                              }}
                            >
                              Remove definition
                            </button>
                          </div>
                        ))}
                    </div>
                    <div className="definition-group">
                      <h5>English definitions</h5>
                      {sense.definitions.filter((definition) => definition.language === "en").length === 0 && (
                        <p className="muted">No English definitions yet.</p>
                      )}
                      {sense.definitions
                        .map((definition, defIndex) => ({ definition, defIndex }))
                        .filter(({ definition }) => definition.language === "en")
                        .map(({ definition, defIndex }) => (
                          <div key={definition.id ?? defIndex} className="card nested">
                            <label className="field">
                              <span>English definition</span>
                              <textarea
                                value={definition.text}
                                onChange={(event) => {
                                  const next = [...sense.definitions];
                                  next[defIndex] = { ...definition, text: event.target.value };
                                  updateDefinitions(index, next);
                                  markDirty();
                                }}
                                onBlur={handleFieldBlur}
                              />
                            </label>
                            <label className="field">
                              <span>Gloss (optional)</span>
                              <input
                                value={definition.gloss ?? ""}
                                onChange={(event) => {
                                  const next = [...sense.definitions];
                                  next[defIndex] = { ...definition, gloss: event.target.value };
                                  updateDefinitions(index, next);
                                  markDirty();
                                }}
                                onBlur={handleFieldBlur}
                                placeholder="Short summary"
                              />
                            </label>
                            <label className="checkbox">
                              <input
                                type="checkbox"
                                checked={definition.is_primary}
                                onChange={(event) => {
                                  const next = sense.definitions.map((item, itemIndex) => {
                                    if (item.language !== "en") {
                                      return item;
                                    }
                                    if (itemIndex === defIndex) {
                                      return { ...item, is_primary: event.target.checked };
                                    }
                                    return { ...item, is_primary: event.target.checked ? false : item.is_primary };
                                  });
                                  updateDefinitions(index, next);
                                  markDirty();
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
                                markDirty();
                              }}
                            >
                              Remove definition
                            </button>
                          </div>
                        ))}
                    </div>
                  </div>
                  <div className="stack" id={`sense-${index}-examples`}>
                    <div className="header-row">
                      <h4>Examples</h4>
                      <div className="actions">
                        <button
                          type="button"
                          className="ghost"
                          onClick={() => updateExamples(index, [...sense.examples, newExample("sw")])}
                        >
                          Add Swahili example
                        </button>
                        <button
                          type="button"
                          className="ghost"
                          onClick={() => updateExamples(index, [...sense.examples, newExample("en")])}
                        >
                          Add example in another language
                        </button>
                      </div>
                    </div>
                    <div className="definition-group" id="section-examples">
                      <h5>Swahili examples</h5>
                      {sense.examples.filter((example) => example.language === "sw").length === 0 && (
                        <p className="muted">No Swahili examples yet.</p>
                      )}
                      {sense.examples
                        .map((example, exampleIndex) => ({ example, exampleIndex }))
                        .filter(({ example }) => example.language === "sw")
                        .map(({ example, exampleIndex }) => (
                          <div key={example.id ?? exampleIndex} className="card nested">
                            <label className="field">
                              <span>Swahili example</span>
                              <textarea
                                value={example.text}
                                onChange={(event) => {
                                  const next = [...sense.examples];
                                  next[exampleIndex] = { ...example, text: event.target.value };
                                  updateExamples(index, next);
                                  markDirty();
                                }}
                                onBlur={handleFieldBlur}
                              />
                            </label>
                            <label className="checkbox">
                              <input
                                type="checkbox"
                                checked={Boolean(example.attested)}
                                onChange={(event) => {
                                  const next = [...sense.examples];
                                  next[exampleIndex] = { ...example, attested: event.target.checked };
                                  updateExamples(index, next);
                                  markDirty();
                                }}
                              />
                              Attested (from a source)
                            </label>
                            {example.attested && (
                              <label className="field">
                                <span>Source</span>
                                <select
                                  value={example.source_id ?? ""}
                                  onChange={(event) => {
                                    const next = [...sense.examples];
                                    next[exampleIndex] = { ...example, source_id: event.target.value || undefined };
                                    updateExamples(index, next);
                                    markDirty();
                                  }}
                                  onBlur={handleFieldBlur}
                                >
                                  <option value="">Select source</option>
                                  {sources.map((source) => (
                                    <option key={source.id} value={source.id}>
                                      {source.name}
                                    </option>
                                  ))}
                                </select>
                              </label>
                            )}
                            <button
                              type="button"
                              className="ghost"
                              onClick={() => {
                                const next = sense.examples.filter((_, itemIndex) => itemIndex !== exampleIndex);
                                updateExamples(index, next);
                                markDirty();
                              }}
                            >
                              Remove example
                            </button>
                          </div>
                        ))}
                    </div>
                    <div className="definition-group">
                      <h5>English examples</h5>
                      {sense.examples.filter((example) => example.language === "en").length === 0 && (
                        <p className="muted">No English examples yet.</p>
                      )}
                      {sense.examples
                        .map((example, exampleIndex) => ({ example, exampleIndex }))
                        .filter(({ example }) => example.language === "en")
                        .map(({ example, exampleIndex }) => (
                          <div key={example.id ?? exampleIndex} className="card nested">
                            <label className="field">
                              <span>English example</span>
                              <textarea
                                value={example.text}
                                onChange={(event) => {
                                  const next = [...sense.examples];
                                  next[exampleIndex] = { ...example, text: event.target.value };
                                  updateExamples(index, next);
                                  markDirty();
                                }}
                                onBlur={handleFieldBlur}
                              />
                            </label>
                            <label className="checkbox">
                              <input
                                type="checkbox"
                                checked={Boolean(example.attested)}
                                onChange={(event) => {
                                  const next = [...sense.examples];
                                  next[exampleIndex] = { ...example, attested: event.target.checked };
                                  updateExamples(index, next);
                                  markDirty();
                                }}
                              />
                              Attested (from a source)
                            </label>
                            {example.attested && (
                              <label className="field">
                                <span>Source</span>
                                <select
                                  value={example.source_id ?? ""}
                                  onChange={(event) => {
                                    const next = [...sense.examples];
                                    next[exampleIndex] = { ...example, source_id: event.target.value || undefined };
                                    updateExamples(index, next);
                                    markDirty();
                                  }}
                                  onBlur={handleFieldBlur}
                                >
                                  <option value="">Select source</option>
                                  {sources.map((source) => (
                                    <option key={source.id} value={source.id}>
                                      {source.name}
                                    </option>
                                  ))}
                                </select>
                              </label>
                            )}
                            <button
                              type="button"
                              className="ghost"
                              onClick={() => {
                                const next = sense.examples.filter((_, itemIndex) => itemIndex !== exampleIndex);
                                updateExamples(index, next);
                                markDirty();
                              }}
                            >
                              Remove example
                            </button>
                          </div>
                        ))}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}

          {activeStep === "Tags & metadata" && (
            <div className="stack">
              <div className="card">
                <h2>Lexeme tags</h2>
                <p className="muted">Tag the lexeme to support browsing and curation.</p>
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
                          markDirty();
                        }}
                      />
                      {tag.name}
                    </label>
                  ))}
                  {tags.length === 0 && <span className="muted">No tags available.</span>}
                </div>
              </div>
              <div className="card">
                <h2>Per-sense tags</h2>
                <div className="stack">
                  {lexeme.senses.length === 0 && <p className="muted">Add senses to tag them.</p>}
                  {lexeme.senses.map((sense, index) => (
                    <div key={sense.id ?? index} className="stack">
                      <h4>Sense {index + 1}</h4>
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
                      </div>
                    </div>
                  ))}
                </div>
              </div>
              <div className="card">
                <h2>Sources & licenses</h2>
                <p className="muted">Attach sources to attested examples to meet publishing requirements.</p>
                {sources.length === 0 && <p className="muted">No sources available.</p>}
                {sources.length > 0 && (
                  <div className="stack">
                    {sources.slice(0, 5).map((source) => (
                      <div key={source.id} className="row">
                        <strong>{source.name}</strong>
                        <span className="muted">{source.description ?? ""}</span>
                      </div>
                    ))}
                    {sources.length > 5 && <p className="muted">{sources.length - 5} more sources available.</p>}
                  </div>
                )}
                {licenses.length > 0 && (
                  <div className="stack">
                    <h4>Licenses</h4>
                    <div className="tag-list">
                      {licenses.map((license) => (
                        <span key={license.id} className="tag-pill">
                          {license.name}
                        </span>
                      ))}
                    </div>
                  </div>
                )}
              </div>
              <div className="card">
                <h2>Internal notes</h2>
                <label className="field">
                  <span>Notes</span>
                  <textarea
                    value={lexeme.notes ?? ""}
                    onChange={(event) => {
                      setLexeme({ ...lexeme, notes: event.target.value });
                      markDirty();
                    }}
                    onBlur={handleFieldBlur}
                    placeholder="Internal notes for editors..."
                  />
                </label>
              </div>
            </div>
          )}

          {activeStep === "Review & publish" && (
            <div className="stack">
              <div className="card preview-card">
                <div className="header-row">
                  <h2>Preview</h2>
                  <span className={`status-chip ${lexeme.status}`}>{lexeme.status}</span>
                </div>
                <div className="preview-header">
                  <h3>{lexeme.lemma || "(Lemma)"}</h3>
                  <span className="muted">{lexeme.part_of_speech || "POS"}</span>
                </div>
                {lexeme.senses.map((sense, index) => {
                  const swDefinitions = sense.definitions.filter(
                    (definition) => definition.language === "sw" && definition.text.trim()
                  );
                  const primarySw = swDefinitions.find((definition) => definition.is_primary) ?? swDefinitions[0];
                  return (
                    <div key={sense.id ?? index} className="preview-sense">
                      <div className="preview-sense__header">
                        <strong>Sense {index + 1}</strong>
                        <div className="chip-row">
                          {sense.domain && <span className="chip">{sense.domain}</span>}
                          {sense.register && <span className="chip">{sense.register}</span>}
                        </div>
                      </div>
                      <p>{primarySw?.text || "Add a Swahili definition"}</p>
                      {sense.examples.some((example) => example.text.trim()) && (
                        <div className="preview-examples">
                          {sense.examples
                            .filter((example) => example.text.trim())
                            .map((example, exampleIndex) => (
                              <p key={`${example.language}-${exampleIndex}`}>
                                <span className="muted">{example.language.toUpperCase()}:</span> {example.text}
                              </p>
                            ))}
                        </div>
                      )}
                    </div>
                  );
                })}
                {lexeme.tags.length > 0 && (
                  <div className="chip-row">
                    {lexeme.tags
                      .map((tagId) => tags.find((tag) => tag.id === tagId))
                      .filter(Boolean)
                      .map((tag) => (
                        <span key={tag?.id} className="chip">
                          {tag?.name}
                        </span>
                      ))}
                  </div>
                )}
              </div>
              <div className="card" id="review-actions">
                <h2>Workflow actions</h2>
                <div className="actions">
                  <button type="button" className="secondary" onClick={handleReview} disabled={reviewing || !lexeme.id}>
                    {reviewing ? "Reviewing..." : "Mark reviewed"}
                  </button>
                  <button type="button" className="primary" onClick={handlePublish} disabled={!canPublish}>
                    {publishing ? "Publishing..." : "Publish"}
                  </button>
                  <button type="button" className="ghost" onClick={handleArchive} disabled={archiving || !lexeme.id}>
                    {archiving ? "Archiving..." : "Archive"}
                  </button>
                  <button type="button" className="ghost" onClick={handleDuplicate} disabled={saving}>
                    Duplicate lexeme
                  </button>
                </div>
                {!mandatoryChecksPassed && (
                  <p className="error">Resolve mandatory checks before publishing.</p>
                )}
              </div>
            </div>
          )}
        </div>

        {activeStep !== "Headword" && (
          <aside className="wizard__panel">
            <div className="panel card">
              <div className="panel__header">
                <h3>Publish readiness</h3>
                <span className={`status-chip ${lexeme.status}`}>{lexeme.status}</span>
              </div>
              <div className="panel__meta">
                <span className={dirty ? "chip warn" : "chip"}>{dirty ? "Unsaved changes" : "All changes saved"}</span>
              </div>
              <div className="panel__checks">
                <h4>Mandatory</h4>
                <ul>
                  {readinessChecks
                    .filter((check) => check.level === "mandatory")
                    .map((check) => (
                      <li key={check.id} className={check.passed ? "pass" : "fail"}>
                        <span>{check.passed ? "✓" : "✕"}</span>
                        <span>{check.label}</span>
                        {!check.passed && check.targetId && (
                          <button type="button" className="link" onClick={() => scrollToTarget(check.targetId)}>
                            Fix
                          </button>
                        )}
                      </li>
                    ))}
                </ul>
                <h4>Recommended</h4>
                <ul>
                  {readinessChecks
                    .filter((check) => check.level === "recommended")
                    .map((check) => (
                      <li key={check.id} className={check.passed ? "pass" : "warn"}>
                        <span>{check.passed ? "✓" : "!"}</span>
                        <span>{check.label}</span>
                        {!check.passed && check.targetId && (
                          <button type="button" className="link" onClick={() => scrollToTarget(check.targetId)}>
                            Fix
                          </button>
                        )}
                      </li>
                    ))}
                </ul>
              </div>
            </div>
          </aside>
        )}
      </div>

      <div className="sticky-footer">
        <div className="actions">
          <button
            type="button"
            className="ghost"
            onClick={() => {
              const currentIndex = steps.indexOf(activeStep);
              if (currentIndex > 0) {
                setActiveStep(steps[currentIndex - 1]);
              }
            }}
          >
            Back
          </button>
          <button type="button" className="primary" onClick={() => void handleSaveDraft()} disabled={saving}>
            {saving ? "Saving..." : "Save draft"}
          </button>
          <button
            type="button"
            className="secondary"
            onClick={() => {
              const currentIndex = steps.indexOf(activeStep);
              if (currentIndex < steps.length - 1) {
                const issue = validateStep();
                if (issue) {
                  setStepError(issue);
                  return;
                }
                setActiveStep(steps[currentIndex + 1]);
              }
            }}
          >
            Next
          </button>
        </div>
        <div className="muted">
          Step {steps.indexOf(activeStep) + 1} of {steps.length}
        </div>
      </div>
    </section>
  );
}
