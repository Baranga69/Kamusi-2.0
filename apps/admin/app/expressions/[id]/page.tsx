"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import LanguageTabs from "../../components/LanguageTabs";
import {
  createAdminClient,
  workflowStatuses,
  type DefinitionInput,
  type ExpressionInput,
  type LanguageCode,
  type WorkflowStatus,
} from "../../../lib/api";
import { useApiKey } from "../../../lib/storage";

const emptyExpression: ExpressionInput = {
  text: "",
  expression_type: "",
  region: "",
  status: "draft",
  meanings: [],
  examples: [],
  link: {},
};

const newMeaning = (language: LanguageCode): DefinitionInput => ({
  language,
  text: "",
  is_primary: false,
});

const newExample = (language: LanguageCode) => ({
  language,
  text: "",
});

export default function ExpressionEditorPage() {
  const params = useParams();
  const router = useRouter();
  const { apiKey, loaded } = useApiKey();
  const [expression, setExpression] = useState<ExpressionInput>(emptyExpression);
  const [activeLang, setActiveLang] = useState<LanguageCode>("sw");
  const [activeExampleLang, setActiveExampleLang] = useState<LanguageCode>("sw");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const client = useMemo(() => (apiKey ? createAdminClient(apiKey) : null), [apiKey]);
  const expressionId = Array.isArray(params?.id) ? params?.id[0] : params?.id;

  useEffect(() => {
    if (!client || !expressionId || expressionId === "new") {
      return;
    }
    let cancelled = false;
    const load = async () => {
      try {
        const data = await client.getExpression(expressionId);
        if (!cancelled) {
          setExpression({
            ...data,
            meanings: data.meanings ?? [],
            examples: data.examples ?? [],
            link: data.link ?? {},
          });
        }
      } catch (err) {
        if (!cancelled) {
          setError("Failed to load expression.");
        }
      }
    };
    load();
    return () => {
      cancelled = true;
    };
  }, [client, expressionId]);

  const handleSave = async () => {
    if (!client) {
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const payload: ExpressionInput = {
        ...expression,
        link: expression.link?.lexeme_id
          ? { lexeme_id: expression.link.lexeme_id }
          : expression.link?.sense_id
            ? { sense_id: expression.link.sense_id }
            : {},
      };
      const result = expressionId && expressionId !== "new"
        ? await client.updateExpression(expressionId, payload)
        : await client.createExpression(payload);
      setExpression(result);
      if (expressionId === "new" && result.id) {
        router.replace(`/expressions/${result.id}`);
      }
    } catch (err) {
      setError("Failed to save expression.");
    } finally {
      setSaving(false);
    }
  };

  const handlePublish = async () => {
    if (!client) {
      return;
    }
    if (!expressionId || expressionId === "new") {
      setError("Save the expression before publishing.");
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const result = await client.publishExpression(expressionId);
      setExpression(result);
    } catch (err) {
      setError("Failed to publish expression.");
    } finally {
      setSaving(false);
    }
  };

  const linkType = expression.link?.lexeme_id ? "lexeme" : expression.link?.sense_id ? "sense" : "none";

  if (!loaded) {
    return <p>Loading...</p>;
  }

  if (!apiKey) {
    return (
      <div className="card">
        <p>
          API key missing. <Link href="/login">Add your API key</Link> to edit expressions.
        </p>
      </div>
    );
  }

  return (
    <section className="stack">
      <div className="header-row">
        <div>
          <h1>{expressionId === "new" ? "New expression" : "Edit expression"}</h1>
          <p className="muted">Edit expression text, meanings, examples, and links.</p>
        </div>
        <div className="actions">
          <button type="button" className="ghost" onClick={() => router.push("/expressions")}>Back</button>
          <button type="button" className="primary" onClick={handleSave} disabled={saving}>
            {saving ? "Saving..." : "Save"}
          </button>
          <button type="button" className="secondary" onClick={handlePublish} disabled={saving}>
            Publish
          </button>
        </div>
      </div>
      {error && <p className="error">{error}</p>}
      <div className="card grid two">
        <label className="field">
          <span>Expression text</span>
          <input
            value={expression.text}
            onChange={(event) => setExpression({ ...expression, text: event.target.value })}
          />
        </label>
        <label className="field">
          <span>Expression type</span>
          <input
            value={expression.expression_type}
            onChange={(event) => setExpression({ ...expression, expression_type: event.target.value })}
            placeholder="methali, semi, nahau"
          />
        </label>
        <label className="field">
          <span>Region</span>
          <input
            value={expression.region ?? ""}
            onChange={(event) => setExpression({ ...expression, region: event.target.value })}
          />
        </label>
        <label className="field">
          <span>Status</span>
          <select
            value={expression.status}
            onChange={(event) => setExpression({ ...expression, status: event.target.value as WorkflowStatus })}
          >
            {workflowStatuses.map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </select>
        </label>
      </div>
      <div className="card stack">
        <h2>Linking</h2>
        <p className="muted">Link this expression to either a lexeme or a sense (not both).</p>
        <div className="grid two">
          <label className="radio">
            <input
              type="radio"
              checked={linkType === "none"}
              onChange={() => setExpression({ ...expression, link: {} })}
            />
            No link
          </label>
          <label className="radio">
            <input
              type="radio"
              checked={linkType === "lexeme"}
              onChange={() => setExpression({ ...expression, link: { lexeme_id: "" } })}
            />
            Link to lexeme
          </label>
          <label className="field">
            <span>Lexeme ID</span>
            <input
              value={expression.link?.lexeme_id ?? ""}
              onChange={(event) => setExpression({ ...expression, link: { lexeme_id: event.target.value } })}
              disabled={linkType !== "lexeme"}
            />
          </label>
          <label className="radio">
            <input
              type="radio"
              checked={linkType === "sense"}
              onChange={() => setExpression({ ...expression, link: { sense_id: "" } })}
            />
            Link to sense
          </label>
          <label className="field">
            <span>Sense ID</span>
            <input
              value={expression.link?.sense_id ?? ""}
              onChange={(event) => setExpression({ ...expression, link: { sense_id: event.target.value } })}
              disabled={linkType !== "sense"}
            />
          </label>
        </div>
      </div>
      <div className="card stack">
        <div className="header-row">
          <h2>Meanings</h2>
          <div className="actions">
            <LanguageTabs active={activeLang} onChange={setActiveLang} />
            <button
              type="button"
              className="ghost"
              onClick={() => setExpression({ ...expression, meanings: [...expression.meanings, newMeaning(activeLang)] })}
            >
              Add meaning
            </button>
          </div>
        </div>
        {expression.meanings
          .map((meaning, index) => ({ meaning, index }))
          .filter(({ meaning }) => meaning.language === activeLang)
          .map(({ meaning, index }) => (
            <div key={meaning.id ?? index} className="card nested">
              <label className="field">
                <span>{activeLang.toUpperCase()} meaning</span>
                <textarea
                  value={meaning.text}
                  onChange={(event) => {
                    const next = [...expression.meanings];
                    next[index] = { ...meaning, text: event.target.value };
                    setExpression({ ...expression, meanings: next });
                  }}
                />
              </label>
              <label className="checkbox">
                <input
                  type="checkbox"
                  checked={meaning.is_primary}
                  onChange={(event) => {
                    const next = expression.meanings.map((item, itemIndex) => {
                      if (item.language !== activeLang) {
                        return item;
                      }
                      if (itemIndex === index) {
                        return { ...item, is_primary: event.target.checked };
                      }
                      return { ...item, is_primary: event.target.checked ? false : item.is_primary };
                    });
                    setExpression({ ...expression, meanings: next });
                  }}
                />
                Primary meaning
              </label>
              <button
                type="button"
                className="ghost"
                onClick={() => {
                  const next = expression.meanings.filter((_, itemIndex) => itemIndex !== index);
                  setExpression({ ...expression, meanings: next });
                }}
              >
                Remove meaning
              </button>
            </div>
          ))}
      </div>
      <div className="card stack">
        <div className="header-row">
          <h2>Examples</h2>
          <div className="actions">
            <LanguageTabs active={activeExampleLang} onChange={setActiveExampleLang} />
            <button
              type="button"
              className="ghost"
              onClick={() => setExpression({ ...expression, examples: [...expression.examples, newExample(activeExampleLang)] })}
            >
              Add example
            </button>
          </div>
        </div>
        {expression.examples
          .map((example, index) => ({ example, index }))
          .filter(({ example }) => example.language === activeExampleLang)
          .map(({ example, index }) => (
            <div key={example.id ?? index} className="card nested">
              <label className="field">
                <span>{activeExampleLang.toUpperCase()} example</span>
                <textarea
                  value={example.text}
                  onChange={(event) => {
                    const next = [...expression.examples];
                    next[index] = { ...example, text: event.target.value };
                    setExpression({ ...expression, examples: next });
                  }}
                />
              </label>
              <button
                type="button"
                className="ghost"
                onClick={() => {
                  const next = expression.examples.filter((_, itemIndex) => itemIndex !== index);
                  setExpression({ ...expression, examples: next });
                }}
              >
                Remove example
              </button>
            </div>
          ))}
      </div>
    </section>
  );
}
