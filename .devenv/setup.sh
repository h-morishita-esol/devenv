#!/usr/bin/env bash
set -euo pipefail

# 開発環境セットアップの統合入口です。
# `.envrc` のリンク作成、Codex 初期化、nvm/Node 初期化を順に実行します。
# `set -euo pipefail` で未定義変数や途中失敗を即時検出し、不完全状態を防ぎます。
GITIGNORE_ENTRIES="
.envrc
"

for entry in $GITIGNORE_ENTRIES; do
  exists_in_gitignore() {
    grep -Fqx -- "$1" "$PWD/.gitignore"
  }
  # 未登録エントリだけを追記して重複を防ぎます。
  if ! exists_in_gitignore "$entry"; then
    printf "%s\n" "$entry" >> "$PWD/.gitignore"
  fi
done

ln -sfn "$PWD/.devenv/run.sh" "$PWD/.envrc"
bash "$PWD/.devenv/setup_nvm.sh"
bash "$PWD/.devenv/setup_codex.sh"
