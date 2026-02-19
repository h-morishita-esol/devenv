#!/usr/bin/env bash
set -euo pipefail

# Codex 用ホーム配下を初期化します。
# 必要ファイルのリンク/コピーと `.gitignore` 追記を行います。
# 先に `run_codex.sh` を読み込み、CODEX_HOME 系の値を確定させます。
source "$PWD/.devenv/run_codex.sh"

# 共有元（`$HOME/.codex`）からシンボリックリンクで扱うファイル群です。
# 共有元の更新を即時反映したい設定・認証情報を対象にします。
SYMLINK_FILES="
AGENTS.md
auth.json
"

# 共有元から実体コピーするファイル群です。
# ローカルで編集する可能性があるため、リンクではなくコピーします。
COPY_FILES="
config.toml
"

# リポジトリの `.gitignore` に追記するエントリです。
# 個人設定・キャッシュ・履歴など VCS 管理しないパスを列挙します。
GITIGNORE_ENTRIES="
$CODEX_HOME_RELATIVE/.personality_migration
$CODEX_HOME_RELATIVE/AGENTS.md
$CODEX_HOME_RELATIVE/auth.json
$CODEX_HOME_RELATIVE/history.jsonl
$CODEX_HOME_RELATIVE/log
$CODEX_HOME_RELATIVE/models_cache.json
$CODEX_HOME_RELATIVE/shell_snapshots
$CODEX_HOME_RELATIVE/skills/.system
$CODEX_HOME_RELATIVE/tmp
$CODEX_HOME_RELATIVE/version.json
"

# Codex ホームディレクトリがなければ作成します。
if [ ! -d "$CODEX_HOME" ]; then
  mkdir -p "$CODEX_HOME"
fi

# `.gitignore` がなければ作成します。
if [ ! -f "$PWD/.gitignore" ]; then
  touch "$PWD/.gitignore"
fi

# 指定ファイルを「未作成時のみ」シンボリックリンクします。
# 既存ファイルがある場合は上書きしません。
for name in $SYMLINK_FILES; do
  dest="$CODEX_HOME/$name"
  src="$HOME/.codex/$name"
  if [ -e "$src" ] && [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    ln -s "$src" "$dest"
  fi
done

# 指定ファイルを「未作成時のみ」コピーします。
# 既存ファイルを壊さないことを優先します。
for name in $COPY_FILES; do
  dest="$CODEX_HOME/$name"
  src="$HOME/.codex/$name"
  if [ -e "$src" ] && [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    cp "$src" "$dest"
  fi
done

# `.gitignore` に同一行があるかを固定文字列の完全一致で判定します。
for entry in $GITIGNORE_ENTRIES; do
  exists_in_gitignore() {
    grep -Fqx -- "$1" "$PWD/.gitignore"
  }
  # 未登録エントリだけを追記して重複を防ぎます。
  if ! exists_in_gitignore "$entry"; then
    printf "%s\n" "$entry" >> "$PWD/.gitignore"
  fi
done

# Codex の npm パッケージをインストールします。
npm install -g @openai/codex
