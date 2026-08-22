# TASK.md — AI引き継ぎメモ

<!--
運用ルール（この文書を更新するAIへ）
1. 更新タイミング: コミットする前に必ず更新する（コミットに含めて記録を残す）
2. 常に上書きする。過去の記録は残さない（履歴はgitが持つ）
3. Doing: 「いまどこを触っているか？完了している状態は？」の事実だけを書く。作業ログや日記にような経緯にしない
4. Next: 次セッションが最初に着手する具体的タスクを先頭に置く。最大5項目
5. Refs: 実在するパスだけを載せる。更新時に消えたファイルへの参照は削除する
6. Notes: 次回セッションで忘れないようにする用のメモ。失敗したこと,次回の教訓にすることなど
7. セクションは Doing / Next / Refs / Notes の4つのみ。全体で50行以内に収める
8. 日本語で書く
-->

## Doing

- ドキュメント整備フェーズが完了した段階。要件定義（`docs/requirements.md`）まで作成済み
- 環境構築済み: Biome / Vitest / Playwright 設定、D1バインディング（`DB`）とリモート・ローカル疎通確認、マイグレーション `migrations/0001_create_subscriptions.sql` 作成済み（デプロイは未実施）
- アプリ本体は未着手: `src/app/App.tsx` はボイラープレートのまま。`src/worker/index.ts` は `/api/health/db` のみ

## Next 

- MVP実装の開始（localStorage版。D1/Hono CRUDはMVP対象外）
- 最初のタスク: Zodスキーマ + データアクセス層（localStorage）の実装。UIから分離すること（FR-10-05, NFR-01）
- 実装前に `docs/requirements.md` の未決事項（TBD-01〜14）のうち、着手範囲に関わるものを決める

## Refs

- `docs/mvp-spec.md` — 原典の製品仕様（矛盾時はこちらが優先）
- `docs/requirements.md` — 検証可能な要件・受け入れ条件 AC-01〜17・未決事項 TBD-01〜14
- `AGENTS.md` / `CLAUDE.md` — コマンド・規約・コミュニケーション言語

## Notes
