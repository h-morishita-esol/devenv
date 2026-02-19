# Requirements Document

## Introduction
本仕様は、`direnv` を起点として Codex 利用に必要な開発環境を自動的に利用可能状態へ遷移させる要件を定義します。対象環境は Node.js（nvm 管理）および Python 3（uv 管理）を含みます。  
前提として `.kiro/steering/` が未配置のため、本ドキュメントはプロジェクト共通ステアリング不在の暫定要件です。
用語定義は `./glossary.md` を参照してください。

## Requirements

### Requirement 1: 開発環境の自動有効化
**Objective:** As a 開発者, I want プロジェクトディレクトリに入るだけで開発環境が有効化されること, so that 手動セットアップなしで作業を開始できる

#### Acceptance Criteria
1. When 開発者が対象プロジェクトディレクトリへ移動したとき, the DEVS shall 開発環境の有効化処理を開始する
2. The DEVS shall 開発者の追加手動操作なしで必要環境を利用可能状態へ遷移させる
3. If 開発環境の有効化に失敗したとき, the DEVS shall 失敗した前提条件または不足要素を識別可能なメッセージで通知する

### Requirement 2: Node.js 実行環境要件
**Objective:** As a 開発者, I want Node.js 実行環境がプロジェクト要件に一致すること, so that Node.js 依存タスクを再現可能に実行できる

#### Acceptance Criteria
1. The DEVS shall Node.js 実行環境を nvm 管理下のバージョンとして提供する
2. While プロジェクト環境が有効な間, the DEVS shall プロジェクト要件と異なる Node.js バージョンを利用しない
3. If 必要な Node.js バージョンが利用不能なとき, the DEVS shall バージョン不整合を明示して環境有効化を失敗扱いにする

### Requirement 3: Python 3 実行環境要件
**Objective:** As a 開発者, I want Python 3 実行環境がプロジェクト要件に一致すること, so that Python 依存タスクを再現可能に実行できる

#### Acceptance Criteria
1. The DEVS shall Python 3 実行環境を uv 管理下のバージョンとして提供する
2. While プロジェクト環境が有効な間, the DEVS shall プロジェクト要件と異なる Python 3 バージョンを利用しない
3. If 必要な Python 3 バージョンが利用不能なとき, the DEVS shall バージョン不整合を明示して環境有効化を失敗扱いにする

### Requirement 4: Codex 開発作業の成立性
**Objective:** As a 開発者, I want Codex を使うための前提ツール群が検証されること, so that 実行時の不整合を早期に検知できる

#### Acceptance Criteria
1. The DEVS shall Codex 開発作業に必要な Node.js と Python 3 の利用可否を環境有効化時に検証する
2. When 必須前提がすべて満たされたとき, the DEVS shall 開発者が同一シェルセッションで両ランタイムを利用可能であることを保証する
3. If 必須前提のいずれかが満たされないとき, the DEVS shall 不完全な状態を成功として扱わない

### Requirement 5: 再現性と安全な再入性
**Objective:** As a 開発者, I want 環境有効化を何度実行しても結果が安定すること, so that 継続開発時の予期せぬ環境変化を防げる

#### Acceptance Criteria
1. When 同一条件で環境有効化を繰り返したとき, the DEVS shall 同一のランタイム選択結果を再現する
2. While 既に環境が有効な間, the DEVS shall 再有効化によって既存セッションに破壊的変更を加えない
3. If 既存環境との差分が検出されたとき, the DEVS shall 差分内容を開発者が判断可能な形で提示する
