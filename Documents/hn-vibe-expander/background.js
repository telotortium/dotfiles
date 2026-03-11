const SETTINGS_KEY = "settings";
const CACHE_PREFIX = "comment-cache:";
const OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses";
const CLEANUP_INTERVAL_MS = 12 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_COMMENTS_PER_BATCH = 6;
const CHARS_PER_TOKEN_ESTIMATE = 3.2;
const STRUCTURED_OUTPUT_OVERHEAD_TOKENS = 800;
const OUTPUT_TOKEN_BASELINE = 128;
const OUTPUT_TOKENS_PER_COMMENT = 320;
const CONTEXT_USAGE_RATIO = 0.85;

const DEFAULT_SETTINGS = Object.freeze({
  apiKey: "",
  model: "gpt-4.1-mini",
  cacheTtlDays: 7,
  lastCleanupAt: 0,
});

const GPT_4_1_MODEL_LIMITS = Object.freeze({
  contextWindow: 1047576,
  maxOutputTokens: 32768,
});

const CONSERVATIVE_MODEL_LIMITS = Object.freeze({
  contextWindow: 8192,
  maxOutputTokens: 2048,
});

const SYSTEM_PROMPT = [
  "You rewrite very short Hacker News comments into longer, more thoughtful versions of the same point.",
  "Preserve the original stance, tone, uncertainty, and level of confidence.",
  "Use the story context and parent comments only to clarify or deepen the same idea.",
  "Do not invent statistics, anecdotes, citations, links, or personal experience.",
  "Do not mention AI, rewriting, or that there was an original shorter comment.",
  "Write plain text only and make each result read like a genuine Hacker News comment.",
  "Aim for roughly 90 to 180 words unless the original comment is especially terse or hedged.",
].join(" ");

chrome.runtime.onInstalled.addListener(() => {
  void initializeSettings();
});

chrome.runtime.onStartup.addListener(() => {
  void cleanupExpiredCache();
});

chrome.action.onClicked.addListener(() => {
  void chrome.runtime.openOptionsPage();
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (!message || typeof message !== "object") {
    return false;
  }

  switch (message.type) {
    case "expand-comments":
      void handleExpandComments(message.payload)
        .then((response) => sendResponse(response))
        .catch((error) => {
          console.error("HN Vibe Expander failed to expand comments:", error);
          sendResponse(toErrorResponse(error));
        });
      return true;

    case "clear-cache":
      void clearCache()
        .then((removed) => sendResponse({ ok: true, removed }))
        .catch((error) => {
          console.error("HN Vibe Expander failed to clear cache:", error);
          sendResponse(toErrorResponse(error));
        });
      return true;

    case "open-options":
      void chrome.runtime
        .openOptionsPage()
        .then(() => sendResponse({ ok: true }))
        .catch((error) => sendResponse(toErrorResponse(error)));
      return true;

    default:
      return false;
  }
});

async function initializeSettings() {
  const settings = await getSettings();
  await chrome.storage.local.set({ [SETTINGS_KEY]: settings });
}

async function handleExpandComments(payload) {
  const settings = await getSettings();
  if (!settings.apiKey) {
    return {
      ok: false,
      error: "missing_api_key",
      message: "Set an OpenAI API key in the extension options before expanding comments.",
    };
  }

  await cleanupExpiredCache({ settings });

  const story = sanitizeStory(payload?.story);
  const comments = Array.isArray(payload?.comments)
    ? payload.comments.map(sanitizeComment).filter(Boolean)
    : [];

  if (!story) {
    return {
      ok: false,
      error: "invalid_story",
      message: "Could not determine the Hacker News story context for this page.",
    };
  }

  if (comments.length === 0) {
    return {
      ok: true,
      results: {},
      meta: {
        requested: 0,
        fromCache: 0,
        generated: 0,
      },
    };
  }

  const cacheKeys = comments.map((comment) => cacheKey(comment.id));
  const cachedEntries = await chrome.storage.local.get(cacheKeys);
  const now = Date.now();
  const results = {};
  const misses = [];

  for (const comment of comments) {
    const sourceHash = buildSourceHash(story, comment);
    const entry = cachedEntries[cacheKey(comment.id)];

    if (isCacheHit(entry, sourceHash, now)) {
      results[comment.id] = {
        expandedText: entry.expandedText,
        source: "cache",
      };
      continue;
    }

    misses.push({
      ...comment,
      sourceHash,
    });
  }

  const cacheWrites = {};
  let generated = 0;
  let skipped = 0;

  if (misses.length > 0) {
    const { expansions: generatedExpansions, skippedCommentIds } = await expandInBatches(
      settings,
      story,
      misses,
    );
    skipped = skippedCommentIds.length;

    for (const comment of misses) {
      const expandedText = generatedExpansions.get(comment.id);
      if (!expandedText) {
        continue;
      }

      generated += 1;
      results[comment.id] = {
        expandedText,
        source: "generated",
      };
      cacheWrites[cacheKey(comment.id)] = {
        commentId: comment.id,
        storyId: story.id,
        sourceHash: comment.sourceHash,
        originalText: comment.text,
        expandedText,
        updatedAt: now,
        expiresAt: now + settings.cacheTtlDays * DAY_MS,
        model: settings.model,
      };
    }

    if (Object.keys(cacheWrites).length > 0) {
      await chrome.storage.local.set(cacheWrites);
    }
  }

  return {
    ok: true,
    results,
    meta: {
      requested: comments.length,
      fromCache: Object.values(results).filter((result) => result.source === "cache").length,
      generated,
      skipped,
    },
  };
}

async function expandInBatches(settings, story, comments) {
  const modelLimits = resolveModelLimits(settings.model);
  const { batches, skippedCommentIds } = buildBatchesForModel(
    story,
    comments,
    modelLimits,
    settings.model,
  );
  const expansions = new Map();
  for (const batch of batches) {
    const batchExpansions = await requestBatchWithFallback(settings, story, batch, modelLimits);
    for (const [commentId, expandedText] of batchExpansions.entries()) {
      expansions.set(commentId, expandedText);
    }
  }
  return {
    expansions,
    skippedCommentIds,
  };
}

async function requestBatchWithFallback(settings, story, batch, modelLimits) {
  try {
    const expansions = await requestBatch(settings, story, batch, modelLimits);
    const missing = batch.filter((comment) => !expansions.has(comment.id));
    if (missing.length === 0) {
      return expansions;
    }

    if (batch.length === 1) {
      throw new Error(`The model did not return an expansion for comment ${batch[0].id}.`);
    }

    const recovered = new Map(expansions);
    for (const comment of missing) {
      const singleExpansion = await requestBatchWithFallback(settings, story, [comment], modelLimits);
      for (const [commentId, expandedText] of singleExpansion.entries()) {
        recovered.set(commentId, expandedText);
      }
    }
    return recovered;
  } catch (error) {
    if (batch.length === 1) {
      throw error;
    }

    const midpoint = Math.ceil(batch.length / 2);
    const left = await requestBatchWithFallback(settings, story, batch.slice(0, midpoint), modelLimits);
    const right = await requestBatchWithFallback(settings, story, batch.slice(midpoint), modelLimits);
    return new Map([...left.entries(), ...right.entries()]);
  }
}

async function requestBatch(settings, story, batch, modelLimits) {
  ensureBatchFitsBudget(story, batch, modelLimits, settings.model);
  const maxOutputTokens = getTargetOutputTokens(batch.length, modelLimits.maxOutputTokens);
  const response = await fetch(OPENAI_RESPONSES_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${settings.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: settings.model,
      instructions: SYSTEM_PROMPT,
      input: buildBatchPrompt(story, batch),
      max_output_tokens: maxOutputTokens,
      text: {
        format: {
          type: "json_schema",
          name: "comment_expansions",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              expansions: {
                type: "array",
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    commentId: { type: "string" },
                    expandedComment: { type: "string" },
                  },
                  required: ["commentId", "expandedComment"],
                },
              },
            },
            required: ["expansions"],
          },
        },
      },
    }),
  });

  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const errorMessage =
      data?.error?.message ||
      `OpenAI API request failed with status ${response.status}.`;
    throw new Error(errorMessage);
  }

  const outputText = extractOutputText(data);
  const parsed = JSON.parse(outputText);
  const expansions = new Map();

  if (!Array.isArray(parsed.expansions)) {
    throw new Error("OpenAI returned a response that did not match the expected schema.");
  }

  for (const item of parsed.expansions) {
    const commentId = typeof item?.commentId === "string" ? item.commentId.trim() : "";
    const expandedText = normalizeGeneratedText(item?.expandedComment);
    if (!commentId || !expandedText) {
      continue;
    }
    expansions.set(commentId, expandedText);
  }

  return expansions;
}

function buildBatchPrompt(story, batch) {
  const promptPayload = {
    story: {
      storyId: story.id,
      title: story.title,
      site: story.site || null,
      url: story.url || null,
      text: story.text || null,
    },
    comments: batch.map((comment) => ({
      commentId: comment.id,
      author: comment.author,
      originalComment: comment.text,
      parentComments: comment.parentChain.map((parent) => ({
        commentId: parent.id,
        author: parent.author,
        text: parent.text,
      })),
    })),
  };

  return [
    "Expand each target comment into a longer Hacker News comment.",
    "Preserve the viewpoint of the original comment instead of arguing with it.",
    "Parent comments and the story are context, not new facts to cite.",
    "Return only valid JSON matching the schema.",
    "",
    JSON.stringify(promptPayload, null, 2),
  ].join("\n");
}

function buildBatchesForModel(story, comments, modelLimits, modelName) {
  const batches = [];
  const skippedCommentIds = [];
  let currentBatch = [];

  for (const comment of comments) {
    const tentativeBatch = [...currentBatch, comment];

    if (
      tentativeBatch.length <= MAX_COMMENTS_PER_BATCH &&
      batchFitsBudget(story, tentativeBatch, modelLimits)
    ) {
      currentBatch = tentativeBatch;
      continue;
    }

    if (currentBatch.length === 0) {
      if (batchFitsBudget(story, [comment], modelLimits)) {
        batches.push([comment]);
      } else {
        console.warn(
          `HN Vibe Expander skipped comment ${comment.id} because its context exceeds the model budget for ${modelName}.`,
        );
        skippedCommentIds.push(comment.id);
      }
      continue;
    }

    batches.push(currentBatch);
    if (batchFitsBudget(story, [comment], modelLimits)) {
      currentBatch = [comment];
    } else {
      console.warn(
        `HN Vibe Expander skipped comment ${comment.id} because its context exceeds the model budget for ${modelName}.`,
      );
      skippedCommentIds.push(comment.id);
      currentBatch = [];
    }
  }

  if (currentBatch.length > 0) {
    batches.push(currentBatch);
  }

  return {
    batches,
    skippedCommentIds,
  };
}

function estimateBatchInputTokens(story, batch) {
  return (
    estimateTextTokens(SYSTEM_PROMPT) +
    estimateTextTokens(buildBatchPrompt(story, batch)) +
    STRUCTURED_OUTPUT_OVERHEAD_TOKENS
  );
}

function estimateTextTokens(text) {
  return Math.ceil(String(text || "").length / CHARS_PER_TOKEN_ESTIMATE);
}

function getTargetOutputTokens(commentCount, maxOutputTokens) {
  return Math.min(
    maxOutputTokens,
    OUTPUT_TOKEN_BASELINE + commentCount * OUTPUT_TOKENS_PER_COMMENT,
  );
}

function getUsableContextWindow(modelLimits) {
  return Math.floor(modelLimits.contextWindow * CONTEXT_USAGE_RATIO);
}

function batchFitsBudget(story, batch, modelLimits) {
  const estimatedInputTokens = estimateBatchInputTokens(story, batch);
  const estimatedOutputTokens = getTargetOutputTokens(batch.length, modelLimits.maxOutputTokens);
  return estimatedInputTokens + estimatedOutputTokens <= getUsableContextWindow(modelLimits);
}

function ensureBatchFitsBudget(story, batch, modelLimits, modelName) {
  if (batchFitsBudget(story, batch, modelLimits)) {
    return;
  }

  if (batch.length === 1) {
    throw new Error(
      `Comment ${batch[0].id} and its thread context are too large for the configured model budget (${modelName}). ` +
        "Use a larger-context model or shorten the amount of surrounding context.",
    );
  }

  throw new Error(
    `Batch of ${batch.length} comments is too large for the configured model budget (${modelName}).`,
  );
}

function resolveModelLimits(modelName) {
  const normalizedModelName = String(modelName || "")
    .trim()
    .toLowerCase();

  if (normalizedModelName.startsWith("gpt-4.1")) {
    return GPT_4_1_MODEL_LIMITS;
  }

  return CONSERVATIVE_MODEL_LIMITS;
}

function sanitizeStory(rawStory) {
  if (!rawStory || typeof rawStory !== "object") {
    return null;
  }

  const id = asCleanString(rawStory.id);
  const title = asCleanString(rawStory.title);
  if (!id || !title) {
    return null;
  }

  return {
    id,
    title,
    url: asCleanString(rawStory.url),
    site: asCleanString(rawStory.site),
    text: asCleanString(rawStory.text),
  };
}

function sanitizeComment(rawComment) {
  if (!rawComment || typeof rawComment !== "object") {
    return null;
  }

  const id = asCleanString(rawComment.id);
  const text = asCleanString(rawComment.text);
  if (!id || !text) {
    return null;
  }

  return {
    id,
    author: asCleanString(rawComment.author) || "unknown",
    text,
    parentChain: Array.isArray(rawComment.parentChain)
      ? rawComment.parentChain
          .map((parent) => ({
            id: asCleanString(parent?.id),
            author: asCleanString(parent?.author) || "unknown",
            text: asCleanString(parent?.text),
          }))
          .filter((parent) => parent.id && parent.text)
      : [],
  };
}

function buildSourceHash(story, comment) {
  return hashString(
    JSON.stringify({
      storyId: story.id,
      title: story.title,
      text: story.text,
      site: story.site,
      commentText: comment.text,
      parentChain: comment.parentChain.map((parent) => ({
        id: parent.id,
        text: parent.text,
      })),
    }),
  );
}

function hashString(value) {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(36);
}

function cacheKey(commentId) {
  return `${CACHE_PREFIX}${commentId}`;
}

function isCacheHit(entry, sourceHash, now) {
  return Boolean(
    entry &&
      typeof entry === "object" &&
      entry.sourceHash === sourceHash &&
      typeof entry.expandedText === "string" &&
      entry.expandedText.trim() &&
      Number.isFinite(entry.expiresAt) &&
      entry.expiresAt > now,
  );
}

async function cleanupExpiredCache({ settings, force = false } = {}) {
  const effectiveSettings = settings || (await getSettings());
  const now = Date.now();

  if (
    !force &&
    Number.isFinite(effectiveSettings.lastCleanupAt) &&
    now - effectiveSettings.lastCleanupAt < CLEANUP_INTERVAL_MS
  ) {
    return 0;
  }

  const allItems = await chrome.storage.local.get(null);
  const expiredKeys = Object.entries(allItems)
    .filter(([key, value]) => {
      return (
        key.startsWith(CACHE_PREFIX) &&
        (!value || !Number.isFinite(value.expiresAt) || value.expiresAt <= now)
      );
    })
    .map(([key]) => key);

  if (expiredKeys.length > 0) {
    await chrome.storage.local.remove(expiredKeys);
  }

  await chrome.storage.local.set({
    [SETTINGS_KEY]: {
      ...effectiveSettings,
      lastCleanupAt: now,
    },
  });

  return expiredKeys.length;
}

async function clearCache() {
  const allItems = await chrome.storage.local.get(null);
  const keys = Object.keys(allItems).filter((key) => key.startsWith(CACHE_PREFIX));
  if (keys.length > 0) {
    await chrome.storage.local.remove(keys);
  }
  return keys.length;
}

async function getSettings() {
  const stored = await chrome.storage.local.get(SETTINGS_KEY);
  return normalizeSettings(stored[SETTINGS_KEY]);
}

function normalizeSettings(rawSettings) {
  const candidate = rawSettings && typeof rawSettings === "object" ? rawSettings : {};
  const cacheTtlDays = Number(candidate.cacheTtlDays);
  const lastCleanupAt = Number(candidate.lastCleanupAt);

  return {
    apiKey: typeof candidate.apiKey === "string" ? candidate.apiKey.trim() : "",
    model:
      typeof candidate.model === "string" && candidate.model.trim()
        ? candidate.model.trim()
        : DEFAULT_SETTINGS.model,
    cacheTtlDays:
      Number.isFinite(cacheTtlDays) && cacheTtlDays > 0
        ? Math.round(cacheTtlDays)
        : DEFAULT_SETTINGS.cacheTtlDays,
    lastCleanupAt:
      Number.isFinite(lastCleanupAt) && lastCleanupAt >= 0
        ? lastCleanupAt
        : DEFAULT_SETTINGS.lastCleanupAt,
  };
}

function extractOutputText(data) {
  if (typeof data?.output_text === "string" && data.output_text.trim()) {
    return data.output_text.trim();
  }

  const parts = [];
  if (Array.isArray(data?.output)) {
    for (const item of data.output) {
      if (!Array.isArray(item?.content)) {
        continue;
      }

      for (const content of item.content) {
        if (
          (content?.type === "output_text" || content?.type === "text") &&
          typeof content.text === "string" &&
          content.text.trim()
        ) {
          parts.push(content.text.trim());
        }
      }
    }
  }

  if (parts.length === 0) {
    throw new Error("OpenAI response did not include any text output.");
  }

  return parts.join("\n");
}

function normalizeGeneratedText(value) {
  return String(value || "")
    .replace(/\r/g, "")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function asCleanString(value) {
  return String(value || "")
    .replace(/\s+/g, " ")
    .trim();
}

function toErrorResponse(error) {
  return {
    ok: false,
    error: "request_failed",
    message: error instanceof Error ? error.message : String(error),
  };
}
