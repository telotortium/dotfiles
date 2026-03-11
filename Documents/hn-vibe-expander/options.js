const SETTINGS_KEY = "settings";
const CACHE_PREFIX = "comment-cache:";

const DEFAULT_SETTINGS = Object.freeze({
  apiKey: "",
  model: "gpt-4.1-mini",
  cacheTtlDays: 7,
  lastCleanupAt: 0,
});

const form = document.getElementById("settings-form");
const apiKeyInput = document.getElementById("api-key");
const modelInput = document.getElementById("model");
const cacheTtlInput = document.getElementById("cache-ttl-days");
const clearCacheButton = document.getElementById("clear-cache");
const cacheSummary = document.getElementById("cache-summary");
const statusMessage = document.getElementById("status");

document.addEventListener("DOMContentLoaded", () => {
  void loadSettings();
});

form.addEventListener("submit", (event) => {
  event.preventDefault();
  void saveSettings();
});

clearCacheButton.addEventListener("click", () => {
  void clearCache();
});

async function loadSettings() {
  const stored = await chrome.storage.local.get(SETTINGS_KEY);
  const settings = normalizeSettings(stored[SETTINGS_KEY]);

  apiKeyInput.value = settings.apiKey;
  modelInput.value = settings.model;
  cacheTtlInput.value = String(settings.cacheTtlDays);
  await refreshCacheSummary();
}

async function saveSettings() {
  const existing = await chrome.storage.local.get(SETTINGS_KEY);
  const currentSettings = normalizeSettings(existing[SETTINGS_KEY]);
  const nextSettings = normalizeSettings({
    ...currentSettings,
    apiKey: apiKeyInput.value,
    model: modelInput.value,
    cacheTtlDays: cacheTtlInput.value,
  });

  await chrome.storage.local.set({
    [SETTINGS_KEY]: nextSettings,
  });

  apiKeyInput.value = nextSettings.apiKey;
  modelInput.value = nextSettings.model;
  cacheTtlInput.value = String(nextSettings.cacheTtlDays);
  showStatus("Settings saved.", "success");
  await refreshCacheSummary();
}

async function clearCache() {
  const response = await chrome.runtime.sendMessage({ type: "clear-cache" });
  if (!response?.ok) {
    showStatus(response?.message || "Could not clear the cache.", "error");
    return;
  }

  showStatus(
    response.removed === 0
      ? "Cache was already empty."
      : `Removed ${response.removed} cached comment${response.removed === 1 ? "" : "s"}.`,
    "success",
  );
  await refreshCacheSummary();
}

async function refreshCacheSummary() {
  const allItems = await chrome.storage.local.get(null);
  const cachedEntries = Object.entries(allItems)
    .filter(([key]) => key.startsWith(CACHE_PREFIX))
    .map(([, value]) => value)
    .filter(Boolean);

  if (cachedEntries.length === 0) {
    cacheSummary.textContent = "No cached comment expansions yet.";
    return;
  }

  const newest = Math.max(...cachedEntries.map((entry) => Number(entry.updatedAt) || 0));
  const oldestExpiry = Math.min(...cachedEntries.map((entry) => Number(entry.expiresAt) || Number.MAX_SAFE_INTEGER));

  const newestLabel = newest ? new Date(newest).toLocaleString() : "unknown";
  const expiryLabel =
    oldestExpiry && oldestExpiry !== Number.MAX_SAFE_INTEGER
      ? new Date(oldestExpiry).toLocaleString()
      : "unknown";

  cacheSummary.textContent =
    `${cachedEntries.length} cached comment expansion${cachedEntries.length === 1 ? "" : "s"}. ` +
    `Newest save: ${newestLabel}. Next expiry: ${expiryLabel}.`;
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

function showStatus(message, tone = "success") {
  statusMessage.textContent = message;
  statusMessage.dataset.tone = tone;
}
