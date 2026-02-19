#!/usr/bin/env bash
set -euo pipefail

# Codex 用ホーム配下の初期化を行います。
# - 必要ファイルのリンク/コピー
# - .gitignore への管理対象外パス追加
# 先に run_codex.sh を読み込み、CODEX_HOME 系の環境変数を確定させます。
source "$PWD/.devenv/run_codex.sh"

# 共有元（$HOME/.codex）からシンボリックリンクで扱うファイル群です。
# 更新を即反映したい設定/認証情報を対象にしています。
SYMLINK_FILES="
AGENTS.md
auth.json
"

# 共有元から実体コピーするファイル群です。
# ローカルで微修正する可能性があるものをリンクではなくコピーしています。
COPY_FILES="
config.toml
"

# リポジトリの .gitignore へ追記するエントリです。
# 個人設定・キャッシュ・履歴など、VCS 管理すべきでないパスを列挙しています。
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

# .gitignore がなければ作成します（後段で追記するため）。
if [ ! -f "$PWD/.gitignore" ]; then
  touch "$PWD/.gitignore"
fi

# 指定ファイルを「未作成時のみ」シンボリックリンクします。
# 既存ファイルがある場合は上書きせず、利用者の状態を尊重します。
for name in $SYMLINK_FILES; do
  dest="$CODEX_HOME/$name"
  src="$HOME/.codex/$name"
  if [ -e "$src" ] && [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    ln -s "$src" "$dest"
  fi
done

# 指定ファイルを「未作成時のみ」コピーします。
# 既存ファイルを壊さないことを最優先にしています。
for name in $COPY_FILES; do
  dest="$CODEX_HOME/$name"
  src="$HOME/.codex/$name"
  if [ -e "$src" ] && [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    cp "$src" "$dest"
  fi
done

# .gitignore に同一行があるかを固定文字列・行完全一致で判定します。
for entry in $GITIGNORE_ENTRIES; do
  exists_in_gitignore() {
    grep -Fqx -- "$1" "$PWD/.gitignore"
  }
  # 未登録エントリのみ追記し、重複行の増殖を防ぎます。
  if ! exists_in_gitignore "$entry"; then
    printf "%s\n" "$entry" >> "$PWD/.gitignore"
  fi
done

# Codex の npm パッケージをインストールします。
npm install -g @openai/codex
