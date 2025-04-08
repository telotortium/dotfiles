#!/usr/bin/env bats

# Ensure that `.bashrc` can be sourced non‑interactively without error.

@test "sourcing .bashrc exits successfully" {
  run bash --noprofile --norc -c "source \"$BATS_TEST_DIRNAME/../.bashrc\""
  [ "$status" -eq 0 ]
}
