#!/usr/bin/env bash
set -euo pipefail

# 開発環境セットアップの統合入口です。
# - .envrc を .devenv/run.sh へ向ける（起動時に必要な環境変数を自動注入）
# - codex 向けホーム配下の初期化
# - nvm と Node.js バージョンの初期化
# `set -euo pipefail` により、未定義変数や途中失敗を即時検出して
# 不完全なセットアップ状態で進むことを防ぎます。
GITIGNORE_ENTRIES="
.envrc
"

for entry in $GITIGNORE_ENTRIES; do
  exists_in_gitignore() {
    grep -Fqx -- "$1" "$PWD/.gitignore"
  }
  # 未登録エントリのみ追記し、重複行の増殖を防ぎます。
  if ! exists_in_gitignore "$entry"; then
    printf "%s\n" "$entry" >> "$PWD/.gitignore"
  fi
done

ln -sfn "$PWD/.devenv/run.sh" "$PWD/.envrc"
bash "$PWD/.devenv/setup_codex.sh"
bash "$PWD/.devenv/setup_nvm.sh"
