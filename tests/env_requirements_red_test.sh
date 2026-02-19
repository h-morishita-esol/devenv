#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FAILURES=0
PASSES=0

pass() {
  PASSES=$((PASSES + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf 'FAIL: %s\n' "$1"
}

assert_file_exists() {
  local path="$1"
  local msg="$2"
  if [ -f "$path" ]; then
    pass "$msg"
  else
    fail "$msg (missing: $path)"
  fi
}

assert_executable() {
  local path="$1"
  local msg="$2"
  if [ -x "$path" ]; then
    pass "$msg"
  else
    fail "$msg (not executable: $path)"
  fi
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local msg="$3"

  if [ ! -f "$path" ]; then
    fail "$msg (missing file: $path)"
    return
  fi

  if grep -Eq "$pattern" "$path"; then
    pass "$msg"
  else
    fail "$msg (pattern not found: $pattern in $path)"
  fi
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local msg="$3"

  if [ ! -f "$path" ]; then
    fail "$msg (missing file: $path)"
    return
  fi

  if grep -Eq "$pattern" "$path"; then
    fail "$msg (forbidden pattern found: $pattern in $path)"
  else
    pass "$msg"
  fi
}

assert_envrc_preserves_non_managed_region() {
  local msg="$1"
  local marker="# codex cli のUserフォルダを指定"
  if [ ! -f ".envrc" ]; then
    fail "$msg (missing file: .envrc)"
    return
  fi
  if grep -Fq "$marker" ".envrc"; then
    pass "$msg"
  else
    fail "$msg (non-managed codex block marker missing)"
  fi
}

assert_any_file_contains() {
  local pattern="$1"
  local msg="$2"
  shift 2

  local found=1
  local path
  for path in "$@"; do
    if [ -f "$path" ] && grep -Eq "$pattern" "$path"; then
      found=0
      break
    fi
  done

  if [ "$found" -eq 0 ]; then
    pass "$msg"
  else
    fail "$msg (pattern not found in expected files: $pattern)"
  fi
}

printf '== env requirements red tests ==\n'

# Requirement 2/3: 配置・管理ブロック・非改変領域
assert_file_exists ".envrc.assets/apply.sh" "R2/R3: apply entrypoint exists"
assert_executable ".envrc.assets/apply.sh" "R3: apply entrypoint is executable"
assert_contains ".envrc" "DEVS_MANAGED_BEGIN|DEVS managed" "R2: .envrc has DEVS managed block marker"
assert_envrc_preserves_non_managed_region "R2: .envrc preserves existing non-managed codex settings"
assert_not_contains ".envrc.assets/activate.sh" "[$]HOME/[.]codex|~/.codex|~/.envrc" "R2: managed assets do not mutate forbidden home scope"

# Requirement 1/4/5: Node/Python version resolution and activation flow
assert_any_file_contains "nvm install" "R4: nvm install is invoked" ".envrc" ".envrc.assets/activate.sh" ".envrc.assets/apply.sh"
assert_any_file_contains "nvm use" "R4: nvm use is invoked" ".envrc" ".envrc.assets/activate.sh" ".envrc.assets/apply.sh"
assert_any_file_contains "uv python list --only-downloads --output-format json" "R5: uv JSON listing is used for latest stable resolution" ".envrc" ".envrc.assets/activate.sh" ".envrc.assets/apply.sh"
assert_any_file_contains "uv python install" "R5: uv python install is invoked" ".envrc" ".envrc.assets/activate.sh" ".envrc.assets/apply.sh"
assert_any_file_contains "uv venv --python" "R1/R5: venv is created with explicit python version" ".envrc" ".envrc.assets/activate.sh" ".envrc.assets/apply.sh"
assert_any_file_contains "source \\.venv/bin/activate" "R1: venv activate command exists" ".envrc" ".envrc.assets/activate.sh" ".envrc.assets/apply.sh"

# Requirement 6: prerequisite tool checks and guidance URLs
assert_any_file_contains "command -v codex|type -P codex" "R6: codex command presence is validated" ".envrc" ".envrc.assets/activate.sh" ".envrc.assets/apply.sh"
assert_any_file_contains "command -v nvm|type -P nvm" "R6: nvm command presence is validated" ".envrc" ".envrc.assets/activate.sh" ".envrc.assets/apply.sh"
assert_any_file_contains "command -v uv|type -P uv" "R6: uv command presence is validated" ".envrc" ".envrc.assets/activate.sh" ".envrc.assets/apply.sh"
assert_any_file_contains "https://github.com/openai/codex|https://github.com/nvm-sh/nvm|https://github.com/astral-sh/uv" "R6: error guidance includes install URLs" ".envrc" ".envrc.assets/activate.sh" ".envrc.assets/apply.sh"

# Requirement 7/3: reentrancy, diff display, backup/restore hooks
assert_any_file_contains "envrc.backup|backup" "R3/R7: backup workflow is defined before updating .envrc" ".envrc.assets/apply.sh" ".envrc"
assert_any_file_contains "diff|cmp" "R7: difference is shown when environment drift is detected" ".envrc" ".envrc.assets/apply.sh" ".envrc.assets/activate.sh"
assert_any_file_contains "runtime diff|runtime selection|node:|python:" "R7: runtime Node/Python selection drift is shown" ".envrc.assets/activate.sh"

printf '\nSummary: pass=%d fail=%d\n' "$PASSES" "$FAILURES"

if [ "$FAILURES" -gt 0 ]; then
  exit 1
fi
