# Shell start‑up enhancement ideas

This document summarises a set of **actionable, independent improvements** you can apply to the Bash/Z‑shell start‑up files in this repository.  Adopt only the items that fix problems you actually experience (slow start‑up, clutter, portability, …).

---

## 1. Performance / start‑up time

| Idea | Concrete step |
|------|---------------|
| **State caching** | Finish the `BASH_LOAD_STATE` experiment – dump functions/variables to a file and `source` it on the next run.  Measured speed‑ups are often 30‑50 %. |
| **Lazy loading** | Wrap heavyweight code in demand‑driven checks.  Example: `[[ $- == *i* ]] && source ~/.fzf.bash` or load Homebrew/MacPorts completion only when `brew`/`port` is found. |
| **Prompt cost** | Either adopt `starship` or keep current colours but compute them once and place the result in a constant string rather than re‑evaluating at every launch. |

## 2. Modularity & maintainability

* **profile.d directory** – Store machine‑specific tweaks in `~/.config/shell/profile.d/*.sh`; have `.bashrc` loop over that directory.
* **Expand `.common.sh`** – Put shared functions there; keep `.bashrc` and `.zshrc` minimal.
* **Move large helpers to `~/bin/`** – Easier unit‑testing and prevents polluting the interactive namespace.

## 3. Portability / best practices

* Provide small helpers like `path_prepend` / `path_append` and avoid duplicate `PATH` entries.
* Adopt XDG base‑dirs to reduce clutter in `$HOME` (`$XDG_STATE_HOME/bash_history`, etc.).
* Only enable interactive‑only options (`shopt -s autocd dirspell globstar`, etc.) when `[[ $- == *i* ]]`.

## 4. Quality & safety

* Run **ShellCheck** in CI (add pre‑commit hook).
* For non‑interactive scripts: `set -o errexit -o nounset -o pipefail`.
* Capture failing commands with `trap 'date +%FT%T  "$BASH_COMMAND" >>$HOME/.basherr' ERR`.

## 5. Productivity features

* Already using **direnv** – pair with `asdf`/`mise` for language version management.
* Replace ad‑hoc navigation tools with **zoxide**; integrate **atuin** for searchable, syncable shell history.
* Add more `fzf` key‑bindings (SSH host picker, `git checkout` helper, …).
* Use `keychain` or `gpg‑agent` for painless SSH key management.
* Extend the macOS `colorfgbg_from_system_appearance` function to also switch LS_COLORS, `bat`, `delta`, etc.

## 6. Testing & CI

* Add a minimal **bats‑core** suite in `test/` that sources `.bashrc` non‑interactively to ensure it never errors.
* GitHub Actions: run ShellCheck + bats.

## 7. Documentation

* Keep the bootstrap instructions (currently in README) up‑to‑date.

---

*Last updated: $(date +%Y‑%m‑%d)*
