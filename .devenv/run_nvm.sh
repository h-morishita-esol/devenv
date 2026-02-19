#!/usr/bin/env bash

# シェル起動時に .nvmrc 指定の Node.js へ切り替える補助スクリプトです。
# source 前提のため、nvm が読み込んだ関数・環境が現在シェルに反映されます。
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# nvm 未導入環境では静かに何もしません。
# 開発者ごとの差分（Node を使わない作業など）を許容する設計です。
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  return 0
fi

. "$NVM_DIR/nvm.sh"

# プロジェクトで Node バージョン固定をしていない場合も何もしません。
if [ ! -f "$PWD/.nvmrc" ]; then
  return 0
fi

# .nvmrc から空白を除去して対象バージョンを確定します。
target="$(tr -d '[:space:]' < "$PWD/.nvmrc")"
if [ -z "$target" ]; then
  return 0
fi

# current: 現在有効な Node バージョン
# resolved: target が実際に解決されるバージョン（alias の場合に実体化）
current="$(nvm current 2>/dev/null || true)"
resolved="$(nvm version "$target" 2>/dev/null || true)"

# 未インストール時は自動インストールせず案内のみ出します。
# シェル起動時に重い処理を走らせないためです。
if [ -z "$resolved" ] || [ "$resolved" = "N/A" ]; then
  echo "[nvm] $target is not installed. run: ./.devenv/setup.sh" >&2
  return 0
fi

# すでに一致している場合は nvm use を呼ばず、起動コストを最小化します。
# 判定は以下を許容します:
# - current == target
# - v$current == target（target が v 付き指定）
# - current == resolved（alias 展開後に一致）
if [ "$current" != "$target" ] && [ "v$current" != "$target" ] && [ "$current" != "$resolved" ]; then
  nvm use --silent "$target" >/dev/null
fi
