#!/usr/bin/env bash

# Codex 関連の環境変数を計算して export するスクリプトです。
# source で読み込む想定のため、呼び出し元シェルに値を残します。
CONFIG_FILE="$PWD/.devenv/config.toml"
# config.toml に設定がなければ既定値 ".codex" を利用します。
CODEX_HOME_RELATIVE=""

if [ -f "$CONFIG_FILE" ]; then
  # TOML から CODEX_HOME_RELATIVE="..." を抽出します。
  # - 先頭/末尾の空白を許容
  # - 最初に見つかった定義のみを採用（head -n1）
  # 取得失敗時は空文字のままとし、後段でデフォルト値にフォールバックします。
  CODEX_HOME_RELATIVE=$(
    sed -n 's/^[[:space:]]*CODEX_HOME_RELATIVE[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_FILE" | head -n1
  )
fi

if [ -z "$CODEX_HOME_RELATIVE" ]; then
  # 設定未定義・空値のどちらでも既定値へ統一します。
  CODEX_HOME_RELATIVE=".codex"
fi

# 相対・絶対の両方を公開します。
# - CODEX_HOME_RELATIVE: リポジトリルート起点の相対パス
# - CODEX_HOME_ABSOLUTE / CODEX_HOME: 実体の絶対パス
export CODEX_HOME_RELATIVE="$CODEX_HOME_RELATIVE"
export CODEX_HOME_ABSOLUTE="$PWD/$CODEX_HOME_RELATIVE"
export CODEX_HOME="$CODEX_HOME_ABSOLUTE"
