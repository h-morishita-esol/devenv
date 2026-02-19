# Requirements Document

## Introduction
本仕様は、`direnv` を起点として Codex 利用に必要な開発環境を自動的に利用可能状態へ遷移させる要件を定義します。対象環境は Node.js（nvm 管理）および Python 3（uv 管理）を含みます。  
前提として `.kiro/steering/` が未配置のため、本ドキュメントはプロジェクト共通ステアリング不在の暫定要件です。
用語定義は `./glossary.md` を参照してください。

## Specification References
- direnv: https://github.com/direnv/direnv
- codex cli: https://github.com/openai/codex
- nvm: https://github.com/nvm-sh/nvm
- uv: https://github.com/astral-sh/uv

## Requirements

### Requirement 1: 開発環境の自動有効化
**Objective:** As a 開発者, I want プロジェクトディレクトリに入るだけで開発環境が有効化されること, so that 手動セットアップなしで作業を開始できる

#### Acceptance Criteria
1. When 開発者が対象プロジェクトディレクトリへ移動したとき, the DEVS shall 開発環境の有効化処理を開始する
2. The DEVS shall 開発者の追加手動操作なしで必要環境を利用可能状態へ遷移させる
3. When 開発者が対象プロジェクトディレクトリへ移動したとき, the DEVS shall `.venv` が未存在なら次の順序で処理する: (a) `.python-version` が未存在の場合は Requirement 5 の Acceptance Criteria 5 および 6 の規則で最新安定版 `X.Y.Z` を解決して `.python-version` を生成する, (b) `uv venv --python "$(cat .python-version)" .venv` を実行して作成する, (c) `source .venv/bin/activate` を実行する
4. If 開発環境の有効化に失敗したとき, the DEVS shall 失敗した前提条件または不足要素を識別可能なメッセージで通知する

### Requirement 2: 成果物配置と非改変領域
**Objective:** As a 開発者, I want DEVS の成果物配置先と禁止領域が明確であること, so that 利用環境の安全性を担保できる

#### Acceptance Criteria
1. The DEVS shall 生成または管理する成果物の配置先を「対象プロジェクト配下」に限定する
2. The DEVS shall 開発環境有効化のためにプロジェクトルートの `.envrc` を修正対象として扱う
3. The DEVS shall `.envrc` の修正を DEVS 管理ブロックに限定し、既存の非管理設定を変更しない
4. The DEVS shall プロジェクト側の補助ファイルを `.envrc.assets/` 配下に配置する
5. The DEVS shall `~/.envrc` および `~/.codex/*` を変更しない
6. The DEVS shall 生成または管理する成果物を少なくとも `.envrc`、`.envrc.assets/*`、`.nvmrc`、`.python-version`、`.venv/`、`.envrc.backup.*` に限定する

### Requirement 3: 配布単位と資産ディレクトリ
**Objective:** As a 開発者, I want プロジェクト配布時のファイル単位が一貫していること, so that 他プロジェクトへの適用を安全に行える

#### Acceptance Criteria
1. The DEVS shall 配布単位を `.envrc.assets/` 配下のファイル群およびプロジェクトルート `.envrc` に適用する管理ブロック定義として扱う
2. The DEVS shall `.envrc` への反映タイミングを「初回導入時」および「`.envrc.assets/` 配下ファイルのハッシュ差分検出時」と定義する
3. The DEVS shall `.envrc.assets/` 更新時の反映トリガーを `direnv allow` の再実行または明示コマンド実行時（例: `./.envrc.assets/apply.sh`）と定義する
4. The DEVS shall `.envrc` 更新前のバックアップ取得手順と復元手順を提供する

### Requirement 4: Node.js 実行環境要件
**Objective:** As a 開発者, I want Node.js 実行環境がプロジェクト要件に一致すること, so that Node.js 依存タスクを再現可能に実行できる

#### Acceptance Criteria
1. The DEVS shall Node.js 実行環境を nvm 管理下のバージョンとして提供する
2. While プロジェクト環境が有効な間, the DEVS shall 次の優先順位で確定した Node.js バージョンのみを利用する: 優先度1=`.nvmrc` が存在し記載値が解決可能ならその値, 優先度2=`.nvmrc` が未存在なら `lts/*` を `.nvmrc` に生成した値; これ以外の Node.js バージョンを利用しない
3. If 必要な Node.js バージョンが利用不能なとき, the DEVS shall バージョン不整合を明示して環境有効化を失敗扱いにする
4. The DEVS shall Node.js の要件定義源をプロジェクトルートの `.nvmrc` に限定する
5. If `.nvmrc` が存在しない場合, the DEVS shall `lts/*` を内容とする `.nvmrc` をプロジェクトルートに自動生成してから環境有効化を継続する
6. If `.nvmrc` の記載値が nvm で解決不能な場合, the DEVS shall 不正な定義を明示して環境有効化を失敗扱いにする
7. The DEVS shall `.nvmrc` に明示されたバージョン指定を `nvm install` および `nvm use` で適用する

### Requirement 5: Python 3 実行環境要件
**Objective:** As a 開発者, I want Python 3 実行環境がプロジェクト要件に一致すること, so that Python 依存タスクを再現可能に実行できる

#### Acceptance Criteria
1. The DEVS shall Python 3 実行環境を uv 管理下のバージョンとして提供する
2. While プロジェクト環境が有効な間, the DEVS shall 次の優先順位で確定した Python 3 バージョンのみを利用する: 優先度1=`.python-version` が存在し記載値が解決可能ならその値, 優先度2=`.python-version` が未存在なら `uv python list --only-downloads --output-format json` から `implementation=cpython` かつ `variant=default` かつ pre-release 除外で選定した最新安定版 `X.Y.Z` を `.python-version` に生成した値; これ以外の Python 3 バージョンを利用しない
3. If 必要な Python 3 バージョンが利用不能なとき, the DEVS shall バージョン不整合を明示して環境有効化を失敗扱いにする
4. The DEVS shall Python 3 の要件定義源をプロジェクトルートの `.python-version` に限定する
5. If `.python-version` が存在しない場合, the DEVS shall `uv python list --only-downloads --output-format json` で取得した候補から `implementation=cpython` かつ `variant=default` かつ pre-release（alpha/beta/rc）を除外した最新安定版 `X.Y.Z` を解決し、その値を `.python-version` に自動生成してから環境有効化を継続する
6. The DEVS shall 「最新安定版」の決定規則を `major, minor, patch` の数値降順ソートで最大値を採用し、同一 `X.Y.Z` が複数存在する場合は実行中プラットフォームに一致する候補を優先し、それでも複数残る場合は `uv python list` の出力順先頭を採用する
7. If `.python-version` の記載値が uv で解決不能な場合, the DEVS shall 不正な定義を明示して環境有効化を失敗扱いにする
8. The DEVS shall `.python-version` に明示されたバージョン指定を `uv python install` および `uv venv --python` で適用する

### Requirement 6: Codex 開発作業の成立性
**Objective:** As a 開発者, I want Codex を使うための前提ツール群が検証されること, so that 実行時の不整合を早期に検知できる

#### Acceptance Criteria
1. The DEVS shall 環境有効化時に `codex`、`nvm`、`uv` のインストール有無を検証する
2. The DEVS shall `nvm` または `uv` が未インストールの場合、環境有効化を失敗扱いにする
3. The DEVS shall `codex` が未インストールの場合、Codex 利用不可を明示して環境有効化を失敗扱いにする
4. The DEVS shall 不足ツールごとに導入手順参照先 URL を含むエラーメッセージを提示する

### Requirement 7: 再現性と安全な再入性
**Objective:** As a 開発者, I want 環境有効化を何度実行しても結果が安定すること, so that 継続開発時の予期せぬ環境変化を防げる

#### Acceptance Criteria
1. When 同一条件で環境有効化を繰り返したとき, the DEVS shall 同一のランタイム選択結果を再現する
2. While 既に環境が有効な間, the DEVS shall 再有効化によって既存セッションに破壊的変更を加えない
3. If 既存環境との差分が検出されたとき, the DEVS shall 差分内容を開発者が判断可能な形で提示する
4. The DEVS shall ランタイムバージョンを明示定義（Node.js は `.nvmrc`、Python は `.python-version`）から決定し、未存在時のみそれぞれ `lts/*` と最新安定版 `X.Y.Z` を初期値として自動生成する
