(async () => {
  if (window.__hnVibeExpanderLoaded) {
    return;
  }
  window.__hnVibeExpanderLoaded = true;

  const storyId = new URL(window.location.href).searchParams.get("id");
  if (!storyId) {
    return;
  }

  const payload = collectPageContext(storyId);
  if (!payload || payload.comments.length === 0) {
    return;
  }

  const statusBanner = ensureStatusBanner();
  updateStatus(
    statusBanner,
    `HN Vibe Expander is checking ${payload.comments.length} short comment${payload.comments.length === 1 ? "" : "s"}...`,
    { tone: "loading" },
  );

  try {
    const response = await chrome.runtime.sendMessage({
      type: "expand-comments",
      payload,
    });

    if (!response?.ok) {
      if (response?.error === "missing_api_key") {
        updateStatus(statusBanner, response.message, {
          tone: "warning",
          actionLabel: "Open options",
          action: openOptions,
        });
        return;
      }

      updateStatus(statusBanner, response?.message || "Comment expansion failed.", {
        tone: "error",
      });
      return;
    }

    const applied = applyExpansions(response.results || {});
    const skipped = Number(response.meta?.skipped) || 0;
    const skippedSuffix =
      skipped > 0
        ? ` ${skipped} comment${skipped === 1 ? "" : "s"} skipped because their context was too large for the configured model budget.`
        : "";
    updateStatus(
      statusBanner,
      applied === 0
        ? `HN Vibe Expander did not find any comments to replace.${skippedSuffix}`
        : `Expanded ${applied} comment${applied === 1 ? "" : "s"} (${response.meta.fromCache} cached, ${response.meta.generated} new).${skippedSuffix}`,
      { tone: "success" },
    );
  } catch (error) {
    console.error("HN Vibe Expander content script failed:", error);
    updateStatus(
      statusBanner,
      error instanceof Error ? error.message : "Comment expansion failed.",
      { tone: "error" },
    );
  }
})();

function collectPageContext(storyId) {
  const story = extractStory(storyId);
  if (!story) {
    return null;
  }

  return {
    story,
    comments: extractEligibleComments(),
  };
}

function extractStory(storyId) {
  const titleLink = document.querySelector(".fatitem .titleline > a");
  const title = normalizeText(titleLink?.textContent);
  if (!title) {
    return null;
  }

  return {
    id: storyId,
    title,
    url: titleLink?.href || "",
    site: normalizeText(document.querySelector(".fatitem .sitestr")?.textContent),
    text: normalizeText(document.querySelector(".fatitem .toptext")?.innerText),
  };
}

function extractEligibleComments() {
  const rows = Array.from(document.querySelectorAll("tr.athing.comtr"));
  const stack = [];
  const eligibleComments = [];

  for (const row of rows) {
    const commentId = row.id;
    if (!commentId) {
      continue;
    }

    const depth = getCommentDepth(row);
    while (stack.length > depth) {
      stack.pop();
    }

    const author = normalizeText(row.querySelector(".hnuser")?.textContent) || "unknown";
    const text = normalizeText(row.querySelector(".commtext")?.innerText);
    const parentChain = stack
      .slice(0, depth)
      .filter((entry) => entry && entry.id && entry.text)
      .map((entry) => ({
        id: entry.id,
        author: entry.author,
        text: entry.text,
      }));

    if (text && countWords(text) < 50) {
      eligibleComments.push({
        id: commentId,
        author,
        text,
        parentChain,
      });
    }

    stack[depth] = {
      id: commentId,
      author,
      text,
    };
    stack.length = depth + 1;
  }

  return eligibleComments;
}

function getCommentDepth(row) {
  const indentCell = row.querySelector(".ind");
  const indentAttribute = Number(indentCell?.getAttribute("indent"));
  if (Number.isFinite(indentAttribute)) {
    return indentAttribute;
  }

  const width = Number(indentCell?.querySelector("img")?.getAttribute("width"));
  if (!Number.isFinite(width)) {
    return 0;
  }

  return Math.max(0, Math.round(width / 40));
}

function countWords(text) {
  return normalizeText(text)
    .split(/\s+/)
    .filter(Boolean).length;
}

function applyExpansions(results) {
  let applied = 0;

  for (const [commentId, expansion] of Object.entries(results)) {
    if (!expansion?.expandedText) {
      continue;
    }

    if (applyExpansion(commentId, expansion.expandedText, expansion.source)) {
      applied += 1;
    }
  }

  return applied;
}

function applyExpansion(commentId, expandedText, source) {
  const row = document.getElementById(commentId);
  const commentContainer = row?.querySelector(".comment");
  const originalBody = row?.querySelector(".comment .commtext");
  if (!row || !commentContainer || !originalBody) {
    return false;
  }

  let shell = commentContainer.querySelector(".hnve-expansion");
  if (!shell) {
    shell = document.createElement("div");
    shell.className = "hnve-expansion";

    const header = document.createElement("div");
    header.className = "hnve-expansion__header";

    const badge = document.createElement("span");
    badge.className = "hnve-expansion__badge";
    badge.textContent = "AI expansion";
    header.appendChild(badge);

    const sourceTag = document.createElement("span");
    sourceTag.className = "hnve-expansion__source";
    sourceTag.textContent = source === "cache" ? "cached" : "new";
    header.appendChild(sourceTag);

    const spacer = document.createElement("span");
    spacer.className = "hnve-expansion__spacer";
    header.appendChild(spacer);

    const toggle = document.createElement("button");
    toggle.type = "button";
    toggle.className = "hnve-expansion__toggle";
    toggle.textContent = "Show original";
    toggle.addEventListener("click", () => {
      const isHidden = originalBody.classList.toggle("hnve-original--hidden");
      toggle.textContent = isHidden ? "Show original" : "Hide original";
    });
    header.appendChild(toggle);

    const body = document.createElement("div");
    body.className = "hnve-expansion__body";

    shell.appendChild(header);
    shell.appendChild(body);
    commentContainer.insertBefore(shell, originalBody);
    originalBody.classList.add("hnve-original--hidden");
  }

  const sourceTag = shell.querySelector(".hnve-expansion__source");
  if (sourceTag) {
    sourceTag.textContent = source === "cache" ? "cached" : "new";
  }

  const body = shell.querySelector(".hnve-expansion__body");
  if (!body) {
    return false;
  }

  body.textContent = "";
  renderPlainText(body, expandedText);
  return true;
}

function renderPlainText(container, text) {
  const paragraphs = String(text)
    .replace(/\r/g, "")
    .split(/\n{2,}/)
    .map((paragraph) => paragraph.trim())
    .filter(Boolean);

  const blocks = paragraphs.length > 0 ? paragraphs : [String(text).trim()];
  for (const paragraph of blocks) {
    const paragraphNode = document.createElement("p");
    const lines = paragraph.split("\n").map((line) => line.trim()).filter(Boolean);
    if (lines.length === 0) {
      continue;
    }

    lines.forEach((line, index) => {
      if (index > 0) {
        paragraphNode.appendChild(document.createElement("br"));
      }
      paragraphNode.append(line);
    });

    container.appendChild(paragraphNode);
  }
}

function ensureStatusBanner() {
  let banner = document.getElementById("hnve-status");
  if (banner) {
    return banner;
  }

  banner = document.createElement("div");
  banner.id = "hnve-status";
  banner.className = "hnve-status";

  const commentTree = document.querySelector(".comment-tree");
  if (commentTree?.parentNode) {
    commentTree.parentNode.insertBefore(banner, commentTree);
  } else {
    document.body.insertBefore(banner, document.body.firstChild);
  }

  return banner;
}

function updateStatus(banner, message, { tone = "info", actionLabel = "", action = null } = {}) {
  if (!banner) {
    return;
  }

  banner.className = `hnve-status hnve-status--${tone}`;
  banner.textContent = "";

  const text = document.createElement("span");
  text.textContent = message;
  banner.appendChild(text);

  if (actionLabel && typeof action === "function") {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "hnve-status__button";
    button.textContent = actionLabel;
    button.addEventListener("click", action);
    banner.appendChild(button);
  }
}

function openOptions() {
  void chrome.runtime.sendMessage({ type: "open-options" });
}

function normalizeText(value) {
  return String(value || "")
    .replace(/\s+/g, " ")
    .trim();
}
