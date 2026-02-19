#!/usr/bin/env bash

CONFIG_FILE="$PWD/.devenv/config.toml"

# .devenv/config.toml から CODEX_HOME_RELATIVE を読み込む
if [ -f "$CONFIG_FILE" ]; then
  CODEX_HOME_RELATIVE=$(
    sed -n 's/^[[:space:]]*CODEX_HOME_RELATIVE[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_FILE" | head -n1
  )
fi

if [ -z "$CODEX_HOME_RELATIVE" ]; then
  CODEX_HOME_RELATIVE=".codex"
fi

# 既存変数名との互換
export CODEX_HOME_RELATIVE
export CODEX_HOME_RELATIVE="$CODEX_HOME_RELATIVE"

# codex cli のUserフォルダの絶対パスを環境変数に設定
export CODEX_HOME_ABSOLUTE="$PWD/$CODEX_HOME_RELATIVE"
export CODEX_HOME="$CODEX_HOME_ABSOLUTE"

# codex cli 用のUser設定ファイルへのシンボリックリンクを作成するためのファイル名
CODEX_SYMLINK_FILES="
AGENTS.md
auth.json
"

# codex cli 用のUser設定ファイルをコピーしてくるためのファイル名
CODEX_COPY_FILES="
config.toml
"

# codex 用のキャッシュファイルを git 管理外とするためのエントリ
CODEX_GITIGNORE_ENTRIES="
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

# codex cli のUserフォルダがなければ作成
if [ ! -d "$CODEX_HOME" ]; then
  mkdir -p "$CODEX_HOME"
fi

# .gitignore がなければ作成
if [ ! -f "$PWD/.gitignore" ]; then
  touch "$PWD/.gitignore"
fi

# codex cli 用のUser設定ファイルへのシンボリックリンクを作成
for name in $CODEX_SYMLINK_FILES; do
  dest="$CODEX_HOME/$name"
  src="$HOME/.codex/$name"
  if [ -e "$src" ] && [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    ln -s "$src" "$dest"
  fi
done

# codex cli 用のUser設定ファイルをコピー
for name in $CODEX_COPY_FILES; do
  dest="$CODEX_HOME/$name"
  src="$HOME/.codex/$name"
  if [ -e "$src" ] && [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    cp "$src" "$dest"
  fi
done

# codex 用のキャッシュファイルを git 管理外とする
for entry in $CODEX_GITIGNORE_ENTRIES; do
  if command -v rg >/dev/null 2>&1; then
    exists_in_gitignore() {
      rg -q -x --fixed-strings "$1" "$PWD/.gitignore"
    }
  else
    exists_in_gitignore() {
      grep -Fqx -- "$1" "$PWD/.gitignore"
    }
  fi

  if ! exists_in_gitignore "$entry"; then
    printf "%s\n" "$entry" >> "$PWD/.gitignore"
  fi
done
