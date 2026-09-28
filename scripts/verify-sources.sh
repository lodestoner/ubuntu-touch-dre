#!/usr/bin/env bash
set -euo pipefail

lock=${1-}
[[ -f "$lock" ]] || { printf 'lock file is missing\n' >&2; exit 1; }

declare -A seen=()
declare -a paths=() urls=() branches=() commits=()
line_no=0
while IFS=$'\t' read -r path url branch commit extra || [[ -n "${path-}" ]]; do
  line_no=$((line_no + 1))
  [[ -n "${path-}" && "${path:0:1}" != "#" ]] || continue
  [[ -z "${extra-}" ]] || { printf 'line %d: too many fields\n' "$line_no" >&2; exit 1; }
  [[ "$path" =~ ^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$ ]] || {
    printf 'line %d: unsafe path\n' "$line_no" >&2; exit 1;
  }
  [[ -z "${seen[$path]+x}" ]] || { printf 'line %d: duplicate path\n' "$line_no" >&2; exit 1; }
  seen[$path]=1
  [[ "$url" == https://* ]] || { printf 'line %d: URL must use HTTPS\n' "$line_no" >&2; exit 1; }
  [[ -n "$branch" ]] || { printf 'line %d: branch is empty\n' "$line_no" >&2; exit 1; }
  [[ "$commit" =~ ^[0-9a-f]{40}$ ]] || { printf 'line %d: commit must be 40 lowercase hex characters\n' "$line_no" >&2; exit 1; }
  combined=${path,,}' '${url,,}
  [[ "$combined" != *billie2* && "$combined" != *sm4250* ]] || {
    printf 'line %d: N100 source is forbidden\n' "$line_no" >&2; exit 1;
  }
  paths+=("$path") urls+=("$url") branches+=("$branch") commits+=("$commit")
done <"$lock"

(( ${#paths[@]} > 0 )) || { printf 'lock has no source records\n' >&2; exit 1; }

for index in "${!paths[@]}"; do
  refs=$(git ls-remote --heads --tags "${urls[$index]}" 2>/dev/null) || {
    printf '%s: remote is unreachable\n' "${paths[$index]}" >&2
    exit 1
  }
  if ! awk -v want="${commits[$index]}" '$1 == want { found=1 } END { exit !found }' <<<"$refs"; then
    printf '%s: commit is not an advertised ref tip\n' "${paths[$index]}" >&2
    exit 1
  fi
done

printf 'verified %d pinned sources\n' "${#paths[@]}"
