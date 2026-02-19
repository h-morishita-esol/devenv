#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PASSES=0
FAILURES=0

pass() {
  PASSES=$((PASSES + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf 'FAIL: %s\n' "$1"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [ "$expected" = "$actual" ]; then
    pass "$msg"
  else
    fail "$msg (expected=$expected actual=$actual)"
  fi
}

printf '== env behavior tests ==\n'

if ! ENVRC_ACTIVATE_TEST_MODE=1 source .envrc.assets/activate.sh; then
  fail "activate.sh can be sourced in test mode"
  printf '\nSummary: pass=%d fail=%d\n' "$PASSES" "$FAILURES"
  exit 1
fi
pass "activate.sh can be sourced in test mode"
if ! ENVRC_APPLY_TEST_MODE=1 source .envrc.assets/apply.sh; then
  fail "apply.sh can be sourced in test mode"
  printf '\nSummary: pass=%d fail=%d\n' "$PASSES" "$FAILURES"
  exit 1
fi
pass "apply.sh can be sourced in test mode"

MOCK_JSON_A='[
  {"implementation":"cpython","variant":"default","version":"3.12.3","platform":"linux-x86_64"},
  {"implementation":"cpython","variant":"default","version":"3.13.0b1","platform":"linux-x86_64"},
  {"implementation":"cpython","variant":"default","version":"3.12.4","platform":"darwin-arm64"},
  {"implementation":"cpython","variant":"default","version":"3.12.4","platform":"linux-x86_64"},
  {"implementation":"pypy","variant":"default","version":"3.12.9","platform":"linux-x86_64"}
]'

resolved_a="$(resolve_latest_python_version_from_json "$MOCK_JSON_A" "linux" "x86_64")"
assert_eq "3.12.4" "$resolved_a" "R5: latest stable excludes pre-release and non-cpython"

MOCK_JSON_B='[
  {"implementation":"cpython","variant":"default","version":"3.11.8","platform":"linux-x86_64"},
  {"implementation":"cpython","variant":"default","version":"3.11.8","platform":"darwin-arm64"}
]'

selected_idx_b="$(resolve_latest_python_record_index "$MOCK_JSON_B" "linux" "x86_64")"
assert_eq "0" "$selected_idx_b" "R5: same X.Y.Z prefers matching platform candidate"

MOCK_JSON_C='[
  {"implementation":"cpython","variant":"default","version":"3.10.14","platform":"unknown"},
  {"implementation":"cpython","variant":"default","version":"3.10.14","platform":"unknown"}
]'

selected_idx_c="$(resolve_latest_python_record_index "$MOCK_JSON_C" "linux" "x86_64")"
assert_eq "0" "$selected_idx_c" "R5: same X.Y.Z unresolved platform falls back to first uv list order"

FORCE_NO_JQ=1
resolved_no_jq="$(resolve_latest_python_version_from_json "$MOCK_JSON_A" "linux" "x86_64")"
unset FORCE_NO_JQ
assert_eq "3.12.4" "$resolved_no_jq" "R5: jq 非存在時も同一規則で最新安定版を選定"

mock_envrc="$(mktemp)"
cat > "$mock_envrc" <<'SRC'
# user setting 1
export FOO=bar
# DEVS_MANAGED_BEGIN
old managed section
# DEVS_MANAGED_END
# user setting 2
SRC

new_envrc="$(render_envrc_with_managed_block "$mock_envrc")"
if printf '%s\n' "$new_envrc" | grep -Fq 'export FOO=bar' && printf '%s\n' "$new_envrc" | grep -Fq '# user setting 2'; then
  pass "R2: managed block update preserves non-managed .envrc region"
else
  fail "R2: managed block update preserves non-managed .envrc region"
fi
rm -f "$mock_envrc"

activate_abs="$ROOT_DIR/.envrc.assets/activate.sh"
tmp_invalid_nvm="$(mktemp -d)"
cat > "$tmp_invalid_nvm/.nvmrc" <<'SRC'
invalid-version
SRC
cat > "$tmp_invalid_nvm/.python-version" <<'SRC'
3.12.4
SRC
mkdir -p "$tmp_invalid_nvm/.venv/bin"
cat > "$tmp_invalid_nvm/.venv/bin/activate" <<'SRC'
#!/usr/bin/env bash
:
SRC
chmod +x "$tmp_invalid_nvm/.venv/bin/activate"

invalid_nvm_output="$(
  cd "$tmp_invalid_nvm" && bash -c '
    set -euo pipefail
    ENVRC_ACTIVATE_TEST_MODE=1 source "'"$activate_abs"'"
    ensure_nvm_loaded() { return 0; }
    codex() { return 0; }
    uv() { return 0; }
    nvm() {
      if [ "$1" = "install" ]; then
        return 1
      fi
      return 0
    }
    main
  ' 2>&1 || true
)"
if printf '%s\n' "$invalid_nvm_output" | grep -Fq '.nvmrc value "invalid-version" cannot be resolved by nvm'; then
  pass "R4: invalid .nvmrc is reported explicitly"
else
  fail "R4: invalid .nvmrc is reported explicitly"
fi
rm -rf "$tmp_invalid_nvm"

tmp_invalid_py="$(mktemp -d)"
cat > "$tmp_invalid_py/.nvmrc" <<'SRC'
lts/*
SRC
cat > "$tmp_invalid_py/.python-version" <<'SRC'
9.9.9
SRC
mkdir -p "$tmp_invalid_py/.venv/bin"
cat > "$tmp_invalid_py/.venv/bin/activate" <<'SRC'
#!/usr/bin/env bash
:
SRC
chmod +x "$tmp_invalid_py/.venv/bin/activate"

invalid_py_output="$(
  cd "$tmp_invalid_py" && bash -c '
    set -euo pipefail
    ENVRC_ACTIVATE_TEST_MODE=1 source "'"$activate_abs"'"
    ensure_nvm_loaded() { return 0; }
    codex() { return 0; }
    nvm() { return 0; }
    uv() {
      if [ "$1" = "python" ] && [ "$2" = "install" ]; then
        return 1
      fi
      return 0
    }
    main
  ' 2>&1 || true
)"
if printf '%s\n' "$invalid_py_output" | grep -Fq '.python-version value "9.9.9" cannot be resolved by uv'; then
  pass "R5: invalid .python-version is reported explicitly"
else
  fail "R5: invalid .python-version is reported explicitly"
fi
rm -rf "$tmp_invalid_py"

printf '\nSummary: pass=%d fail=%d\n' "$PASSES" "$FAILURES"
if [ "$FAILURES" -gt 0 ]; then
  exit 1
fi
