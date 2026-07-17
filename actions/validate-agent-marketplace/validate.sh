#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$PWD}"
skill_root="$repo_root/${SKILL_ROOT:-skills}"

if [[ ! -d "$skill_root" ]]; then
  echo "ERROR: skill root does not exist: $skill_root" >&2
  exit 1
fi

status=0
count=0

while IFS= read -r skill_file; do
  count=$((count + 1))
  skill_dir="$(dirname "$skill_file")"
  dir_name="$(basename "$skill_dir")"
  frontmatter_end="$(awk 'NR > 1 && /^---[[:space:]]*$/ { print NR; exit }' "$skill_file")"
  name="$(awk '
    NR == 1 { next }
    /^---[[:space:]]*$/ { exit }
    /^name:[[:space:]]*/ { sub(/^name:[[:space:]]*/, ""); print; exit }
  ' "$skill_file")"

  if ! head -1 "$skill_file" | grep -qx -- '---'; then
    echo "ERROR: $skill_file must start with YAML frontmatter" >&2
    status=1
  fi
  if [[ -z "$frontmatter_end" ]]; then
    echo "ERROR: $skill_file has no closing frontmatter delimiter" >&2
    status=1
  elif ! awk -v end="$frontmatter_end" 'NR > end && $0 !~ /^[[:space:]]*$/ { found=1 } END { exit !found }' "$skill_file"; then
    echo "ERROR: $skill_file has no instruction body after frontmatter" >&2
    status=1
  fi
  if [[ -z "$name" ]]; then
    echo "ERROR: $skill_file is missing name" >&2
  elif [[ "$name" != "$dir_name" ]]; then
    echo "ERROR: $skill_file name '$name' does not match directory '$dir_name'" >&2
    status=1
  elif ! [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "ERROR: $skill_file has invalid name '$name'" >&2
    status=1
  fi
  if ! awk '
    NR == 1 { next }
    /^---[[:space:]]*$/ { exit(description_found && description_content ? 0 : 1) }
    /^description:[[:space:]]*/ {
      description_found=1
      value=$0
      sub(/^description:[[:space:]]*/, "", value)
      if (value != "" && value !~ /^[>|][+-]?[0-9]*$/) description_content=1
      next
    }
    description_found && $0 ~ /^[[:space:]]+[^[:space:]]/ { description_content=1 }
    END { exit(description_found && description_content ? 0 : 1) }
  ' "$skill_file"; then
    echo "ERROR: $skill_file is missing a non-empty description" >&2
    status=1
  fi
done < <(find "$skill_root" -mindepth 2 -maxdepth 2 -name SKILL.md -print | sort)

if [[ "$count" -eq 0 ]]; then
  echo "ERROR: no skills found under $skill_root" >&2
  exit 1
fi

validate_json_manifest() {
  local relative_path="$1"
  local manifest="$repo_root/$relative_path"
  if [[ ! -f "$manifest" ]]; then
    return 0
  fi
  if ! jq empty "$manifest" >/dev/null; then
    echo "ERROR: invalid JSON manifest: $relative_path" >&2
    status=1
  fi
}

validate_json_manifest "$CLAUDE_MARKETPLACE_FILE"
validate_json_manifest "$CLAUDE_PLUGIN_FILE"

validate_plugin_bundle() {
  local plugin_root_name="$1"
  local plugin_root="$repo_root/$plugin_root_name"
  local manifest="$plugin_root/.codex-plugin/plugin.json"
  local cursor_manifest="$plugin_root/.cursor-plugin/plugin.json"
  local bundle_skills="$plugin_root/skills"

  if [[ ! -d "$plugin_root" ]]; then
    echo "ERROR: plugin root does not exist: $plugin_root_name" >&2
    status=1
    return
  fi
  if [[ ! -d "$bundle_skills" ]]; then
    echo "ERROR: plugin has no skills directory: $plugin_root_name/skills" >&2
    status=1
    return
  fi
  if [[ ! -f "$manifest" && ! -f "$cursor_manifest" ]]; then
    echo "ERROR: plugin has no supported plugin manifest: $plugin_root_name" >&2
    status=1
  fi
  validate_json_manifest "${plugin_root_name}/.codex-plugin/plugin.json"
  validate_json_manifest "${plugin_root_name}/.cursor-plugin/plugin.json"

  if ! diff -ru "$skill_root" "$bundle_skills" >/dev/null; then
    echo "ERROR: plugin skills are out of sync with $SKILL_ROOT: $plugin_root_name/skills" >&2
    status=1
  fi
}

if [[ -n "${CODEX_PLUGIN_ROOT:-}" ]]; then
  validate_plugin_bundle "$CODEX_PLUGIN_ROOT"
fi
if [[ -n "${CURSOR_PLUGIN_ROOT:-}" && "${CURSOR_PLUGIN_ROOT}" != "${CODEX_PLUGIN_ROOT:-}" ]]; then
  validate_plugin_bundle "$CURSOR_PLUGIN_ROOT"
fi

if [[ "$status" -ne 0 ]]; then
  exit "$status"
fi
echo "Validated $count skills and configured marketplace manifests."
