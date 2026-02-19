#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVRC_PATH="$ROOT_DIR/.envrc"
ASSET_DIR="$ROOT_DIR/.envrc.assets"
MANAGED_FILE="$ASSET_DIR/envrc.managed"
HASH_FILE="$ASSET_DIR/.assets.sha256"
QUIET=0

if [ "${1:-}" = "--quiet" ]; then
  QUIET=1
fi

log() {
  if [ "$QUIET" -eq 0 ]; then
    printf '%s\n' "$1"
  fi
}

write_managed_file() {
  cat > "$MANAGED_FILE" <<'MANAGED'
#!/usr/bin/env bash
source "$PWD/.envrc.assets/activate.sh"
MANAGED
}

render_managed_block() {
  cat <<'BLOCK'
# DEVS_MANAGED_BEGIN
if [ -x "$PWD/.envrc.assets/apply.sh" ]; then
  "$PWD/.envrc.assets/apply.sh" --quiet
fi
source_env "$PWD/.envrc.assets/envrc.managed"
# DEVS_MANAGED_END
BLOCK
}

render_envrc_with_managed_block() {
  local source_envrc_path="$1"
  local tmp_file
  tmp_file="$(mktemp)"

  if [ -f "$source_envrc_path" ] && grep -q 'DEVS_MANAGED_BEGIN' "$source_envrc_path" && grep -q 'DEVS_MANAGED_END' "$source_envrc_path"; then
    awk '
      BEGIN { in_block=0 }
      /# DEVS_MANAGED_BEGIN/ { in_block=1; next }
      /# DEVS_MANAGED_END/ { in_block=0; next }
      in_block==0 { print }
    ' "$source_envrc_path" | sed '/^$/N;/^\n$/D' > "$tmp_file"
    if [ -s "$tmp_file" ]; then
      printf '\n' >> "$tmp_file"
    fi
    render_managed_block >> "$tmp_file"
  else
    if [ -f "$source_envrc_path" ]; then
      cat "$source_envrc_path" > "$tmp_file"
      if [ -s "$tmp_file" ]; then
        printf '\n' >> "$tmp_file"
      fi
    fi
    render_managed_block >> "$tmp_file"
  fi

  cat "$tmp_file"
  rm -f "$tmp_file"
}

replace_managed_block() {
  local tmp_file
  tmp_file="$(mktemp)"
  render_envrc_with_managed_block "$ENVRC_PATH" > "$tmp_file"

  if [ -f "$ENVRC_PATH" ] && cmp -s "$ENVRC_PATH" "$tmp_file"; then
    rm -f "$tmp_file"
    return 0
  fi

  if [ -f "$ENVRC_PATH" ]; then
    local backup_path
    backup_path="$ROOT_DIR/.envrc.backup.$(date +%Y%m%d%H%M%S)"
    cp "$ENVRC_PATH" "$backup_path"
    log "backup: $backup_path"
    log "restore: cp '$backup_path' '$ENVRC_PATH'"
  fi

  if [ -f "$ENVRC_PATH" ]; then
    log 'diff (.envrc):'
    diff -u "$ENVRC_PATH" "$tmp_file" || true
  fi

  mv "$tmp_file" "$ENVRC_PATH"
}

compute_assets_hash() {
  (
    cd "$ASSET_DIR"
    find . -maxdepth 1 -type f ! -name '.assets.sha256' -print0 \
      | sort -z \
      | xargs -0 sha256sum
  ) | sha256sum | awk '{print $1}'
}

main() {
  mkdir -p "$ASSET_DIR"
  write_managed_file
  chmod +x "$ASSET_DIR/activate.sh" "$ASSET_DIR/apply.sh" "$MANAGED_FILE"

  local old_hash=""
  if [ -f "$HASH_FILE" ]; then
    old_hash="$(cat "$HASH_FILE")"
  fi

  local new_hash
  new_hash="$(compute_assets_hash)"

  if [ "$new_hash" != "$old_hash" ]; then
    log 'diff detected in .envrc.assets; updating .envrc managed block'
    replace_managed_block
    printf '%s\n' "$new_hash" > "$HASH_FILE"
  fi
}

if [ "${ENVRC_APPLY_TEST_MODE:-0}" != "1" ]; then
  main "$@"
fi
