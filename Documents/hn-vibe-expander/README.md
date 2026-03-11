# HN Vibe Expander

Chrome extension that rewrites Hacker News comments shorter than 50 words into
longer, more thoughtful versions using OpenAI. Thanks @abtinf for [inspiration](https://news.ycombinator.com/item?id=47341987).

## What it does

- Runs automatically on `https://news.ycombinator.com/item?id=...`
- Expands every eligible short comment on the page
- Uses the story plus the full parent-comment chain as context for each rewrite
- Caches generated rewrites in `chrome.storage.local`
- Reuses cached rewrites on later visits instead of calling the API again
- Expires cached comments after 7 days by default
- Sizes batches against both estimated input and output token budgets before calling the API

## Project layout

- `manifest.json`: MV3 extension manifest
- `background.js`: OpenAI requests, token-aware batching, caching, expiry cleanup
- `content.js`: HN parsing and in-page replacement
- `content.css`: injected styles for rewritten comments
- `options.html`, `options.css`, `options.js`: API key and cache settings

## Install

1. Open `chrome://extensions`
2. Enable Developer mode
3. Click `Load unpacked`
4. Select this folder.
5. Open the extension options and set your OpenAI API key

## Notes

- Default model: `gpt-4.1-mini`
- API keys and cached comments stay local to your Chrome profile
- The extension keeps the original HN comment hidden behind a `Show original` toggle
