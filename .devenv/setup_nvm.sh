#!/usr/bin/env bash
set -euo pipefail

# nvm / Node.js のセットアップ担当です。
# 目的:
# - nvm があれば読み込む
# - .nvmrc がなければ既定値（lts/*）を作成
# - 指定バージョンをインストールし、即時利用可能にする
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# リポジトリの .gitignore へ追記するエントリです。
GITIGNORE_ENTRIES="
.nvmrc
node_modules
"

# .gitignore がなければ作成します（後段で追記するため）。
if [ ! -f "$PWD/.gitignore" ]; then
  touch "$PWD/.gitignore"
fi

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

# nvm 未導入時は失敗扱いにせず案内のみで終了します。
# このスクリプト単体の失敗で全セットアップを止めないためです。
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "[nvm] not found: $NVM_DIR/nvm.sh" >&2
  echo "[nvm] install nvm first: https://github.com/nvm-sh/nvm" >&2
  exit 0
fi

. "$NVM_DIR/nvm.sh"

# .nvmrc がない場合は LTS 最新系列を既定値として採用します。
if [ ! -f "$PWD/.nvmrc" ]; then
  printf "lts/*\n" > "$PWD/.nvmrc"
fi

# 空白除去後に空なら設定異常として停止します。
target="$(tr -d '[:space:]' < "$PWD/.nvmrc")"
if [ -z "$target" ]; then
  echo "[nvm] .nvmrc is empty" >&2
  exit 1
fi

# npm も最新化しつつ対象 Node を導入します。
# 以降の `npm` 系コマンドが即利用できるように use まで実行します。
nvm install "$target" --latest-npm
nvm use --silent "$target" >/dev/null
