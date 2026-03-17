# Development Environment

## 結論
- このリポジトリは、プロジェクトルートに `./.devenv` をシンボリックリンクして使います。
- プロジェクトごとの設定は `./.devenvrc` に置きます。
- 初回は `./.devenv/setup.sh` 実行後に `direnv allow` を手動実行します。

## 前提条件
- 必須
  - `bash`
  - `git`
  - `direnv`
- Node.js 関連
  - `nvm`
  - `npm`
- Python 関連
  - `uv`

## 使用方法
1. このリポジトリを任意のディレクトリに clone します。

   ```bash
   git clone https://github.com/taturou/devenv.git /path/to/devenv
   ```

2. 開発プロジェクトのルートで `.devenv` シンボリックリンクを作成します。

   ```bash
   cd /path/to/your/project
   ln -s /path/to/devenv/.devenv ./.devenv
   ```

3. 設定テンプレートをコピーして `./.devenvrc` を作成します。

   ```bash
   cp ./.devenv/template/.devenvrc ./.devenvrc
   ```

4. 必要に応じて `./.devenvrc` を編集します。

5. 初回セットアップを実行します。

   ```bash
   ./.devenv/setup.sh
   ```

6. `direnv` を手動で有効化します。

   ```bash
   direnv allow
   ```

## 日常運用
- プロジェクトに `cd` すると `.envrc` 経由で以下が自動反映されます。
- `.nvmrc` があれば該当 Node バージョンへ切替します。未導入時は案内のみ出します。
- `.python-version` と `.venv` が整っていれば仮想環境を有効化します。
- `CODEX_HOME` と関連 PATH を設定します。
- `clangd.enable = true` のとき `.clangd` を更新します。
- `serena.enable = true` のとき `.serena/project.yml` の `ignored_paths` を同期します。

## 設定ファイル
- テンプレート: `./.devenv/template/.devenvrc`
- 例: `./.devenv/template/.devenvrc.emcos`
- 実ファイル: `./.devenvrc`

### `[codex]`
- `codex_home_relative`
  - codex cli のホームディレクトリです。
  - プロジェクトルートからの相対パスで指定します。
  - 未設定または空文字のときは `.codex` を使います。

### `[git]`
- `user_name`
  - リポジトリローカルの `user.name` に反映します。
  - 未設定または空文字のときは `$HOME/.gitconfig` の値を使います。
- `user_email`
  - リポジトリローカルの `user.email` に反映します。
  - 未設定または空文字のときは `$HOME/.gitconfig` の値を使います。

### `[clangd]`
- `enable`
  - `true` のとき `.clangd` を生成します。
- `exclude_path`
  - `.clangd` の `CompileFlags.PathMatch` 生成対象から除外するパスです。
- `background_skip_path`
  - `.clangd` に `Index.Background: Skip` を出力するパスです。

### `[serena]`
- `enable`
  - `true` のとき `.serena/project.yml` の `ignored_paths` を同期します。
- `ignored_paths`
  - `.serena/project.yml` に反映するパスです。

## `setup.sh` の仕様
- `./.devenvrc` が無い場合はエラー終了します。
- エラー時は `cp ./.devenv/template/.devenvrc ./.devenvrc` を案内します。
- `.envrc` シンボリックリンクを作成します。
- `direnv allow` は実行しません。

## codex cli メタデータ仕様
- `./.devenvrc`
  - 利用者が `./.devenv/template/.devenvrc` からコピーして作成します。
- `$CODEX_HOME/config.toml`
  - コピー元: `./.devenv/codex/template/config.toml`
  - 未作成時のみコピーします。
- `$CODEX_HOME/AGENTS.md`
  - リンク元: `$HOME/.codex/AGENTS.md`
  - 元ファイルが存在し、未作成時のみシンボリックリンクを作成します。
- `$CODEX_HOME/auth.json`
  - リンク元: `$HOME/.codex/auth.json`
  - 元ファイルが存在し、未作成時のみシンボリックリンクを作成します。
- `.clangd`
  - `./.devenvrc` の `[clangd].enable = true` かつ `python3` 利用可能時に、シェル入場ごとに再生成します。
- `.serena/project.yml`
  - `./.devenvrc` の `[serena].enable = true` かつ `python3` 利用可能時に、`ignored_paths` のみ追記・同期します。

## よくある失敗と対処
- `[devenv] './.devenvrc' がありません。`
  - `cp ./.devenv/template/.devenvrc ./.devenvrc` を実行してください。
- `[nvm] not found`
  - `nvm` をインストールし、`$HOME/.nvm/nvm.sh` を配置してください。
- `[uv] not found`
  - `uv` をインストールしてください。
- `[uv] .venv not found` / `python ... is not installed`
  - `./.devenv/setup.sh` を再実行してください。
- `[clangd] failed to generate .clangd`
  - `python3` の存在と `./.devenvrc` の `[clangd]` 設定を確認してください。
- `[serena] failed to update .serena/project.yml`
  - `.serena/project.yml` が存在するか、`./.devenvrc` の `[serena].ignored_paths` が配列になっているか確認してください。
