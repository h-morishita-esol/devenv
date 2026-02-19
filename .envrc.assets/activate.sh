#!/usr/bin/env bash

set -euo pipefail

RUNTIME_STATE_FILE="$PWD/.envrc.assets/.runtime-selection"

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "$s"
}

normalize_os() {
  local os="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    linux*) printf 'linux' ;;
    darwin*|macos*) printf 'darwin' ;;
    msys*|mingw*|cygwin*|windows*|win32*) printf 'windows' ;;
    *) printf '%s' "$os" ;;
  esac
}

normalize_arch() {
  local arch="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$arch" in
    x86_64|amd64) printf 'x86_64' ;;
    aarch64|arm64) printf 'arm64' ;;
    *) printf '%s' "$arch" ;;
  esac
}

platform_match_score() {
  local platform_blob="$1"
  local host_os="$2"
  local host_arch="$3"
  local blob="$(printf '%s' "$platform_blob" | tr '[:upper:]' '[:lower:]')"

  if [[ "$blob" == *"$host_os"* ]] && [[ "$blob" == *"$host_arch"* ]]; then
    printf '2'
  elif [[ "$blob" == *"$host_os"* ]]; then
    printf '1'
  else
    printf '0'
  fi
}

resolve_latest_python_record_index_jq() {
  local json="$1"
  local host_os="$2"
  local host_arch="$3"

  printf '%s' "$json" | jq -r --arg host_os "$host_os" --arg host_arch "$host_arch" '
    to_entries
    | [ .[]
        | .value as $v
        | ($v.version // "") as $version
        | select(($v.implementation // "") == "cpython")
        | select(($v.variant // "") == "default")
        | select($version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
        | {
            idx: .key,
            version: $version,
            ver: ($version | split(".") | map(tonumber)),
            platform_blob: (([
              ($v.platform // ""),
              ($v.os // ""),
              ($v.target // ""),
              ($v.triple // ""),
              ($v.arch // ""),
              ($v.architecture // "")
            ] | join(" ")) | ascii_downcase)
          }
      ]
    | map(. + {
        score: (if (.platform_blob | contains($host_os) and contains($host_arch)) then 2
                elif (.platform_blob | contains($host_os)) then 1
                else 0 end)
      })
    | sort_by(.ver[0], .ver[1], .ver[2], .score, (-.idx))
    | reverse
    | .[0].idx // empty
  '
}

resolve_latest_python_record_index_perl() {
  local json="$1"
  local host_os="$2"
  local host_arch="$3"

  JSON_INPUT="$json" HOST_OS="$host_os" HOST_ARCH="$host_arch" perl -MJSON::PP -e '
    use strict;
    use warnings;

    my $json = $ENV{JSON_INPUT} // q{};
    my $host_os = lc($ENV{HOST_OS} // q{});
    my $host_arch = lc($ENV{HOST_ARCH} // q{});

    my $rows = eval { JSON::PP::decode_json($json) };
    if ($@ || ref($rows) ne "ARRAY") {
      print q{};
      exit 0;
    }

    my @cand;
    for (my $i = 0; $i < scalar(@$rows); $i++) {
      my $r = $rows->[$i];
      next if ref($r) ne "HASH";
      my $impl = $r->{implementation} // q{};
      my $variant = $r->{variant} // q{};
      my $version = $r->{version} // q{};
      next unless $impl eq "cpython";
      next unless $variant eq "default";
      next unless $version =~ /^([0-9]+)\.([0-9]+)\.([0-9]+)$/;

      my ($maj, $min, $pat) = ($1 + 0, $2 + 0, $3 + 0);
      my @parts = (
        lc($r->{platform} // q{}),
        lc($r->{os} // q{}),
        lc($r->{target} // q{}),
        lc($r->{triple} // q{}),
        lc($r->{arch} // q{}),
        lc($r->{architecture} // q{})
      );
      my $blob = join q{ }, @parts;
      my $score = 0;
      if (index($blob, $host_os) >= 0 && index($blob, $host_arch) >= 0) {
        $score = 2;
      } elsif (index($blob, $host_os) >= 0) {
        $score = 1;
      }

      push @cand, {
        idx => $i,
        maj => $maj,
        min => $min,
        pat => $pat,
        score => $score,
      };
    }

    if (!@cand) {
      print q{};
      exit 0;
    }

    @cand = sort {
      $b->{maj} <=> $a->{maj}
      || $b->{min} <=> $a->{min}
      || $b->{pat} <=> $a->{pat}
      || $b->{score} <=> $a->{score}
      || $a->{idx} <=> $b->{idx}
    } @cand;

    print $cand[0]->{idx};
  '
}

resolve_latest_python_record_index() {
  local json="$1"
  local host_os="$(normalize_os "${2:-$(uname -s 2>/dev/null || echo unknown)}")"
  local host_arch="$(normalize_arch "${3:-$(uname -m 2>/dev/null || echo unknown)}")"

  if [ "${FORCE_NO_JQ:-0}" != "1" ] && command -v jq >/dev/null 2>&1; then
    resolve_latest_python_record_index_jq "$json" "$host_os" "$host_arch"
    return
  fi

  if ! command -v perl >/dev/null 2>&1; then
    printf 'ERROR: neither jq nor perl is available to parse uv JSON output\nInstall: https://github.com/jqlang/jq or provide perl with JSON::PP\n' >&2
    printf ''
    return 0
  fi

  resolve_latest_python_record_index_perl "$json" "$host_os" "$host_arch"
}

resolve_latest_python_version_from_json() {
  local json="$1"
  local host_os="${2:-$(normalize_os "$(uname -s 2>/dev/null || echo unknown)")}"
  local host_arch="${3:-$(normalize_arch "$(uname -m 2>/dev/null || echo unknown)")}"
  local idx
  idx="$(resolve_latest_python_record_index "$json" "$host_os" "$host_arch")"
  if [ -z "$idx" ]; then
    printf ''
    return 0
  fi

  if [ "${FORCE_NO_JQ:-0}" != "1" ] && command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r --argjson idx "$idx" '.[ $idx ].version // empty'
    return
  fi

  JSON_INPUT="$json" IDX="$idx" perl -MJSON::PP -e '
    use strict;
    use warnings;
    my $rows = eval { JSON::PP::decode_json($ENV{JSON_INPUT} // q{}) };
    if ($@ || ref($rows) ne "ARRAY") {
      print q{};
      exit 0;
    }
    my $i = ($ENV{IDX} // q{}) + 0;
    if ($i < 0 || $i >= scalar(@$rows)) {
      print q{};
      exit 0;
    }
    my $v = $rows->[$i]{version} // q{};
    print $v;
  '
}

resolve_latest_python_version() {
  local json
  json="$(uv python list --only-downloads --output-format json)"
  resolve_latest_python_version_from_json "$json"
}

ensure_nvm_loaded() {
  if command -v nvm >/dev/null 2>&1; then
    return 0
  fi

  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
  fi

  if ! command -v nvm >/dev/null 2>&1; then
    printf 'ERROR: missing required command: nvm\nInstall: https://github.com/nvm-sh/nvm\n' >&2
    return 1
  fi
}

ensure_runtime_selection_diff() {
  local node_version="$1"
  local python_version="$2"
  local tmp_file
  tmp_file="$(mktemp)"

  {
    printf 'node:%s\n' "$node_version"
    printf 'python:%s\n' "$python_version"
  } > "$tmp_file"

  if [ -f "$RUNTIME_STATE_FILE" ]; then
    if ! cmp -s "$RUNTIME_STATE_FILE" "$tmp_file"; then
      printf 'runtime diff detected:\n' >&2
      diff -u "$RUNTIME_STATE_FILE" "$tmp_file" || true
    fi
  else
    printf 'runtime selection initialized:\n' >&2
    cat "$tmp_file" >&2
  fi

  mv "$tmp_file" "$RUNTIME_STATE_FILE"
}

main() {
  ensure_nvm_loaded

  if ! command -v codex >/dev/null 2>&1 && ! type -P codex >/dev/null 2>&1; then
    printf 'ERROR: missing required command: codex\nInstall: https://github.com/openai/codex\n' >&2
    return 1
  fi
  if ! command -v uv >/dev/null 2>&1 && ! type -P uv >/dev/null 2>&1; then
    printf 'ERROR: missing required command: uv\nInstall: https://github.com/astral-sh/uv\n' >&2
    return 1
  fi

  if [ ! -f .nvmrc ]; then
    printf 'lts/*\n' > .nvmrc
  fi

  NODE_VERSION="$(trim "$(cat .nvmrc)")"
  if [ -z "$NODE_VERSION" ]; then
    printf 'ERROR: .nvmrc is empty and cannot be resolved by nvm\n' >&2
    return 1
  fi

  if ! nvm install "$NODE_VERSION"; then
    printf 'ERROR: .nvmrc value "%s" cannot be resolved by nvm (install failed)\n' "$NODE_VERSION" >&2
    return 1
  fi
  if ! nvm use "$NODE_VERSION"; then
    printf 'ERROR: .nvmrc value "%s" cannot be resolved by nvm (use failed)\n' "$NODE_VERSION" >&2
    return 1
  fi

  if [ ! -f .python-version ]; then
    PYTHON_VERSION="$(resolve_latest_python_version)"
    if [ -z "${PYTHON_VERSION:-}" ]; then
      printf 'ERROR: failed to resolve latest stable Python from uv JSON list\nInstall: https://github.com/astral-sh/uv\n' >&2
      return 1
    fi
    printf '%s\n' "$PYTHON_VERSION" > .python-version
  fi

  PYTHON_VERSION="$(trim "$(cat .python-version)")"
  if [ -z "$PYTHON_VERSION" ]; then
    printf 'ERROR: .python-version is empty and cannot be resolved by uv\n' >&2
    return 1
  fi

  if ! uv python install "$PYTHON_VERSION"; then
    printf 'ERROR: .python-version value "%s" cannot be resolved by uv\nInstall: https://github.com/astral-sh/uv\n' "$PYTHON_VERSION" >&2
    return 1
  fi

  if [ ! -d .venv ]; then
    if ! uv venv --python "$(cat .python-version)" .venv; then
      printf 'ERROR: failed to create .venv with Python "%s" via uv venv --python\n' "$PYTHON_VERSION" >&2
      return 1
    fi
  fi

  ensure_runtime_selection_diff "$NODE_VERSION" "$PYTHON_VERSION"

  source .venv/bin/activate
}

if [ "${ENVRC_ACTIVATE_TEST_MODE:-0}" != "1" ]; then
  main "$@"
fi
