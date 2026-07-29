#!/usr/bin/env bash
# Shared-skills drift warning. Host global config is checked by each host repo.

out="$("$HOME/.agents/bin/agents-sync" --doctor 2>&1)"
[ "$?" -eq 0 ] ||
  printf 'shared skills：偵測到 source／Claude skill-link 異常——\n%s\n' "$out" >&2
exit 0
