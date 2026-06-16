#!/usr/bin/env bats

setup() {
  command_path="$BATS_TEST_DIRNAME/../bin/git-clean-merged-branches"
  mock_bin="$BATS_TEST_TMPDIR/bin"
  export MOCK_GH_LOG="$BATS_TEST_TMPDIR/gh.log"
  export MOCK_GIT_LOG="$BATS_TEST_TMPDIR/git.log"
  export MOCK_WORKTREE="$BATS_TEST_TMPDIR/merged-worktree"
  export MOCK_GH_INDICES='0,2'
  mkdir -p "$mock_bin" "$MOCK_WORKTREE"
  : >"$MOCK_GH_LOG"
  : >"$MOCK_GIT_LOG"

  cat >"$mock_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$MOCK_GH_LOG"
case "$1 $2" in
  'repo view') printf '%s\n' 'acme/repo' ;;
  'api graphql') printf '%s' "$MOCK_GH_INDICES" | tr ',' '\n' ;;
  *) exit 1 ;;
esac
EOF

  cat >"$mock_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$MOCK_GIT_LOG"
case "$1 $2" in
  'rev-parse --is-inside-work-tree') exit 0 ;;
  'for-each-ref --format=%(refname:short)')
    printf '%s\n' branch-merged branch-open branch-closed
    ;;
  'worktree list')
    printf 'worktree %s\0HEAD deadbeef\0branch refs/heads/branch-merged\0\0' "$MOCK_WORKTREE"
    ;;
  'worktree remove'|'branch -D') exit 0 ;;
  '-c core.hooksPath=/dev/null') exit 0 ;;
  *) exit 1 ;;
esac
EOF

  cat >"$mock_bin/direnv" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  chmod +x "$mock_bin/gh" "$mock_bin/git" "$mock_bin/direnv"
  export PATH="$mock_bin:$PATH"
  unset VIRTUAL_ENV
}

@test "dry run maps batched GraphQL aliases back to local branches" {
  run "$command_path" --dry-run

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'Would delete local branch branch-merged' ]
  [ "${lines[1]}" = 'Would delete local branch branch-closed' ]
  [ "${#lines[@]}" -eq 2 ]
  [ "$(grep -c '^api graphql ' "$MOCK_GH_LOG")" -eq 1 ]
  grep -q 'head0=branch-merged' "$MOCK_GH_LOG"
  grep -q 'head1=branch-open' "$MOCK_GH_LOG"
  grep -q 'head2=branch-closed' "$MOCK_GH_LOG"
}

@test "worktree inventory is read once before sequential deletion" {
  run "$command_path"

  [ "$status" -eq 0 ]
  [ "$(grep -c '^worktree list ' "$MOCK_GIT_LOG")" -eq 1 ]
  grep -q "^worktree remove $MOCK_WORKTREE$" "$MOCK_GIT_LOG"
  grep -q '^branch -D branch-merged$' "$MOCK_GIT_LOG"
  grep -q '^branch -D branch-closed$' "$MOCK_GIT_LOG"
}
