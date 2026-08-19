# v-subsc 実装計画（認証導入前まで）

## 0. このドキュメントについて

`docs/mvp-spec.md`（何を作るか）に対して、本書は **どの順番で作るか** を管理する。

- 範囲: 空のボイラープレート状態 → サブスクリプションCRUDがフロント/バックエンド両方で動く状態まで
- 終点: **ユーザー認証を実装する直前**（認証そのものは本計画の対象外）
- 進め方: マイルストーン（M0〜M8）を上から順に完了させる。各マイルストーンは「単体で `pnpm dev` 上で動作確認できる状態」で区切る
- チェックボックスはそのまま進捗管理に使う。完了時は該当マイルストーンの「状態」を更新する

関連ドキュメント:

- `docs/mvp-spec.md` — 機能仕様（正）。本書と矛盾した場合は仕様書を優先し、本書を修正する
- `AGENTS.md` — コマンド、ディレクトリ規約、命名、コミット規約

---

## 1. ゴールとスコープ

### 1.1 このフェーズのゴール

1. サブスクリプションを追加・一覧・編集・削除できる（CRUD）
2. カテゴリ追加、無料期間、JPY/USD別集計、ソートが仕様どおり動く
3. データが `localStorage` からCloudflare D1へ、**UIをほぼ書き換えずに**移行できている
4. ブラウザ → Hono API → D1 のデータフローが成立している

### 1.2 スコープ外（このフェーズでは作らない）

- ユーザー認証・セッション・ユーザーごとのデータ分離
- 為替レート取得、USD→JPY換算
- 通知、Cron Triggers、Queues
- 検索、高度なフィルター、グラフ・分析
- 解約済み契約の管理、カテゴリの編集・削除
- 複数ユーザー共有

> 注: D1はこのフェーズでは「単一の匿名ユーザーが使うテーブル」として設計する。ただし認証導入時に破壊的変更が最小になるよう、**M5でテーブルに `user_id` 相当の拡張余地を残す**（詳細は §9）。

---

## 2. マイルストーン全体像

| ID | 名称 | 主な成果 | 目安 | 状態 |
|---|---|---|---|---|
| M0 | プロジェクト基盤整備 | ボイラープレート除去、ディレクトリ構成、Zod導入 | 0.5日 | 未着手 |
| M1 | ドメインモデル + データアクセス層 | 型/スキーマ/リポジトリ抽象 + localStorage実装 | 1日 | 未着手 |
| M2 | 一覧表示とサマリー | 表形式の一覧、契約数・JPY合計・USD合計 | 1日 | 未着手 |
| M3 | 新規追加 | 追加モーダル、通貨切替、カテゴリ追加、無料期間 | 1.5日 | 未着手 |
| M4 | 編集・削除・ソート | 編集モーダル、削除確認、ソート切替 | 1日 | 未着手 |
| — | **MVP完成判定** | 仕様書 §14 の10項目をすべて満たす | — | — |
| M5 | D1スキーマ + マイグレーション | DB作成、バインディング、テーブル定義 | 0.5日 | 未着手 |
| M6 | Hono CRUD API | `/api/subscriptions`、`/api/categories`、サーバー検証 | 1.5日 | 未着手 |
| M7 | データ層のAPI差し替え | localStorage実装 → API実装へ切替 | 1日 | 未着手 |
| M8 | 品質仕上げとデプロイ確認 | エラー処理、ローディング、本番デプロイ | 1日 | 未着手 |

```mermaid
flowchart LR
  M0[M0 基盤] --> M1[M1 データ層]
  M1 --> M2[M2 一覧]
  M2 --> M3[M3 追加]
  M3 --> M4[M4 編集/削除/ソート]
  M4 --> MVP{{MVP完成判定}}
  MVP --> M5[M5 D1スキーマ]
  M5 --> M6[M6 Hono API]
  M6 --> M7[M7 API差し替え]
  M7 --> M8[M8 仕上げ/デプロイ]
  M8 --> AUTH([認証: 次フェーズ])
```

M4までが仕様書のMVP範囲、M5以降が「認証の手前まで」の追加分。**M4時点で一度コミット/デプロイして区切る**ことを推奨する。

---

## 3. 共通の設計方針

### 3.1 ディレクトリ構成（目標）

```text
src/
  app/                          # ブラウザ側
    App.tsx
    components/                 # 汎用UI（Modal, Button, IconButton ...）
    features/
      subscriptions/
        SubscriptionTable.tsx
        SubscriptionRow.tsx
        SubscriptionFormModal.tsx
        DeleteConfirmModal.tsx
        SummaryBar.tsx
        useSubscriptions.ts     # 状態管理フック（データ層の唯一の呼び出し口）
      categories/
        useCategories.ts
    data/                       # ★データアクセス層（UIから分離）
      types.ts                  # Repository インターフェース
      localStorageRepository.ts # M1で実装
      apiRepository.ts          # M7で実装
      index.ts                  # 使用する実装を1か所で切り替える
  shared/                       # ★フロント/Worker 共通
    schema/
      subscription.ts           # Zodスキーマ + 型
      category.ts
    domain/
      money.ts                  # 通貨・金額の整形/検証
      freeTrial.ts              # 無料期間終了日の計算
  worker/
    index.ts                    # Honoエントリ（ルート登録のみ）
    routes/
      subscriptions.ts
      categories.ts
    db/
      subscriptionQueries.ts    # D1アクセス（SQLはここに閉じる）
      categoryQueries.ts
migrations/                     # D1マイグレーション（M5で作成）
```

**設計上の最重要ルール**: UIコンポーネントは `src/app/data/` の外にあるストレージ実装を直接importしない。UIは常にリポジトリインターフェース越しに扱う。これがM7の差し替えを「1ファイルの切り替え」に収める前提になる。

### 3.2 データモデル

```ts
type Currency = "JPY" | "USD";

type Subscription = {
  id: string;              // crypto.randomUUID()
  name: string;            // 1〜60文字
  priceMinor: number;      // 最小通貨単位の整数（JPY: 円, USD: セント）
  currency: Currency;
  categoryId: string;
  nextBillingDate: string; // "YYYY-MM-DD"
  freeTrialDays: number;   // 0以上の整数（0 = 無料期間なし）
  createdAt: string;       // ISO8601。「追加順」ソートと無料期間終了日の基準
  updatedAt: string;       // ISO8601
};

type Category = {
  id: string;
  name: string;
  isPreset: boolean;       // プリセット6種は true
};
```

**決定事項: 金額は最小通貨単位の整数で保持する（`priceMinor`）。**
理由は、USDの小数（15.99）を浮動小数のまま合計すると誤差が出るため、およびD1のカラム型をINTEGERに揃えられるため。表示・入力時のみ `shared/domain/money.ts` で `1599 ⇄ "15.99"` を変換する。JPYは指数0（`1500` = ¥1,500）、USDは指数2（`1599` = $15.99）。この方針をM1で入れておくと、M5〜M7で型を作り直さずに済む。

**プリセットカテゴリ**（仕様書 §8）: 動画 / 音楽 / ソフトウェア / ゲーム / クラウド / その他。プリセットは定数として `shared/` に持ち、ユーザー追加分のみ永続化する。

**無料期間終了日**: `createdAt + freeTrialDays 日`。`freeTrialDays === 0` は「無料期間なし」として一覧で空欄扱い。

### 3.3 リポジトリインターフェース（M1で確定、M7で実装差し替え）

```ts
interface SubscriptionRepository {
  list(): Promise<Subscription[]>;
  create(input: SubscriptionInput): Promise<Subscription>;
  update(id: string, input: SubscriptionInput): Promise<Subscription>;
  remove(id: string): Promise<void>;
}

interface CategoryRepository {
  list(): Promise<Category[]>;
  create(name: string): Promise<Category>;
}
```

localStorage実装でも**戻り値をPromiseにする**。同期実装のまま作るとM7でUI側の呼び出しを全部書き換えることになるため、最初から非同期前提で組む。

---

## 4. M0 — プロジェクト基盤整備

**目的**: ボイラープレートを片付け、以降のマイルストーンが載る土台を作る。

### 作業

- [ ] `src/app/App.tsx` / `App.css` のテンプレート表示を除去し、アプリのシェル（ヘッダー + メイン領域）にする
- [ ] `package.json` の `name` / `description` を `v-subsc` の内容へ更新（現在 `vite-react-template` のまま）
- [ ] 依存追加: `pnpm add zod`
- [ ] `src/shared/` を作成し、**tsconfigのincludeを更新**する
  - `tsconfig.app.json` の `include` に `src/shared` を追加
  - `tsconfig.worker.json` の `include` に `src/shared` を追加
  - （現状 include は `src/app` / `src/worker` のみのため、追加しないと型チェックから漏れる）
- [ ] パスエイリアス `@/` を設定（`vite.config.ts` の `resolve.alias` と各tsconfigの `paths` の両方）
- [ ] `src/app/components/` `src/app/features/` `src/app/data/` `src/shared/` の空ディレクトリ構成を用意
- [ ] （推奨・任意）Vitest導入: `pnpm add -D vitest`。M1以降のドメインロジック（金額変換、無料期間計算、合計）は純関数なのでテストの費用対効果が高い

### 完了条件

- `pnpm lint` / `pnpm build` が通る
- `pnpm dev` でテンプレート文言が消えたシェルが表示される
- `src/shared/` に置いたファイルが app / worker の両方からimportでき、型チェックされる

---

## 5. M1 — ドメインモデルとデータアクセス層（localStorage）

**目的**: UIを書く前に「データの形」と「データの出し入れ」を確定させる。ここが後半の移行コストを決める。

### 作業

- [ ] `src/shared/schema/subscription.ts`: Zodスキーマを定義
  - `subscriptionSchema`（保存形）と `subscriptionInputSchema`（フォーム入力形）を分ける
  - 検証: `name` 必須1〜60文字 / `priceMinor` 0より大きい整数 / `currency` は `"JPY" | "USD"` / `nextBillingDate` は `YYYY-MM-DD` 形式 / `freeTrialDays` は0以上の整数
- [ ] `src/shared/schema/category.ts`: カテゴリスキーマ + プリセット定数
- [ ] `src/shared/domain/money.ts`: `toMinor(input, currency)` / `formatMoney(priceMinor, currency)` / 通貨記号（¥ / $）/ JPYは整数のみ・USDは小数2桁まで
- [ ] `src/shared/domain/freeTrial.ts`: `freeTrialEndDate(createdAt, freeTrialDays)`
- [ ] `src/app/data/types.ts`: §3.3のリポジトリインターフェース
- [ ] `src/app/data/localStorageRepository.ts`: 実装
  - キー: `v-subsc:subscriptions` / `v-subsc:categories`
  - 読み込み時にZodで検証し、壊れたデータは捨てて空配列にフォールバック（`JSON.parse` の例外も握る）
  - `id` は `crypto.randomUUID()`、`createdAt` / `updatedAt` はISO文字列
- [ ] `src/app/data/index.ts`: 使用する実装をexportする1か所（M7でここだけ差し替える）
- [ ] `src/app/features/subscriptions/useSubscriptions.ts`: 一覧の読み込み・追加・更新・削除・ローディング/エラー状態を持つフック

### 完了条件

- UIなしで、ブラウザのコンソールからリポジトリ経由の追加/取得/更新/削除ができる
- 不正な形のデータを `localStorage` に手で入れてもアプリがクラッシュしない
- （Vitest導入時）金額変換・無料期間計算・合計のテストが通る

---

## 6. M2 — 一覧表示とサマリー

**目的**: 保存済みデータを読んで表示する側を完成させる（仕様書 §4, §5）。

### 作業

- [ ] `SummaryBar.tsx`: 契約数 / JPY合計 / USD合計 / 「新規追加」ボタン（この時点ではボタンは無効 or 何もしない）
  - **JPYとUSDは換算せず別々に合計する**（仕様書 §5, §7）
- [ ] `SubscriptionTable.tsx` / `SubscriptionRow.tsx`: 表形式、カード状コンテナ内に配置
  - 列: サービス名 / カテゴリ / 料金 / 次回請求日 / 無料期間
  - 料金は通貨記号つきで整形表示（`formatMoney`）
  - 無料期間は「30日（〜2026/09/18）」のように残り日数か終了日を表示。0日は空欄
- [ ] 初期並び順 = 追加順（`createdAt` 昇順）
- [ ] 0件時の空状態表示（「まだ登録がありません」＋追加導線）
- [ ] レイアウト/スタイルの方針を1つに決めて適用（§10 の未決事項1を参照）

### 完了条件

- `localStorage` に手で入れたデータが一覧とサマリーに正しく反映される
- リロードしても表示が保持される
- 合計値がJPY/USDで独立して正しい

---

## 7. M3 — 新規追加（モーダル・カテゴリ・無料期間）

**目的**: Create を完成させる（仕様書 §6〜§9）。

### 作業

- [ ] `components/Modal.tsx`: 汎用モーダル（Escで閉じる、背景クリックで閉じる、フォーカストラップ、`aria-modal`）
  - M4の編集・削除確認でも再利用するため、ここで汎用化しておく
- [ ] `SubscriptionFormModal.tsx`: 追加フォーム
  - サービス名（テキスト・必須）
  - 料金（数値・必須）＋ 左に通貨記号、右に通貨セレクト。初期値JPY
  - 通貨変更で記号が切り替わる / **金額は自動換算しない**
  - JPYは整数のみ、USDは小数2桁まで許可
  - カテゴリ（セレクト・必須）
  - 次回請求日（日付・必須）
  - 無料期間（`−` / `+` ボタン、初期値0、0未満にできない）
- [ ] カテゴリの新規追加UI（セレクト内の「＋新しいカテゴリ」など）。追加分は永続化し以降の選択肢に出る
  - MVPではカテゴリ名の編集・削除は作らない（仕様書 §8）
- [ ] Zodスキーマでの入力検証 + フィールド単位のエラー表示
- [ ] 送信でリポジトリの `create` を呼び、一覧・サマリーへ即時反映

### 完了条件

- 追加 → 一覧に出る → リロードしても残る
- JPY/USD両方で登録でき、記号と桁が仕様どおり
- 独自カテゴリを追加でき、次回のフォームでも選べる
- 必須項目が空、料金が0以下、無料期間を負にする、などが弾かれる

---

## 8. M4 — 編集・削除・ソート（MVP完成）

**目的**: Update / Delete と一覧操作を完成させ、仕様書 §14 を満たす。

### 作業

- [ ] 行ホバーで右端に操作ボタン（Pencil / Trash 系アイコン）を表示（仕様書 §10）
  - タッチ環境ではホバーが効かないため、常時表示へのフォールバックを入れる
- [ ] 編集: `SubscriptionFormModal` を**そのまま再利用**し、現在値を初期値として表示（新規/編集をpropsで分岐）
- [ ] 削除: `DeleteConfirmModal` を表示し、確定した場合のみ削除（即時削除しない・仕様書 §11）
- [ ] ソート切替UI: 追加順 / 請求日順（仕様書 §4）
- [ ] 編集・削除後にサマリーが再計算される

### 完了条件（＝ MVP完成判定・仕様書 §14）

- [ ] 1. サブスクリプションを追加できる
- [ ] 2. 追加したデータが一覧に表示される
- [ ] 3. 再読み込みしてもデータが残る
- [ ] 4. 登録内容を編集できる
- [ ] 5. 確認モーダルを経由して削除できる
- [ ] 6. JPY / USDを切り替えて料金を登録できる
- [ ] 7. ユーザー独自カテゴリを追加できる
- [ ] 8. 無料期間を設定できる
- [ ] 9. 追加順 / 請求日順でソートできる
- [ ] 10. 契約数、JPY合計、USD合計が正しく表示される

`pnpm lint` / `pnpm build` / `pnpm check` を通し、ここで区切りのコミットを打つ。

---

## 9. M5 — D1スキーマとマイグレーション

**目的**: 本番の保存先を用意する。まだアプリからは使わない。

### 作業

- [ ] `pnpm wrangler d1 create v-subsc-db` でDBを作成
- [ ] `wrangler.json` にバインディングを追加

```jsonc
{
  "d1_databases": [
    {
      "binding": "DB",
      "database_name": "v-subsc-db",
      "database_id": "<作成時に表示されるUUID>",
      "migrations_dir": "migrations"
    }
  ]
}
```

- [ ] `pnpm cf-typegen` を実行し `worker-configuration.d.ts` を再生成（`Env.DB` が型に載る）
- [ ] `pnpm wrangler d1 migrations create v-subsc-db create_initial_tables` でマイグレーションファイル生成
- [ ] テーブル定義を記述

```sql
CREATE TABLE categories (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  is_preset   INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL
);

CREATE TABLE subscriptions (
  id                TEXT PRIMARY KEY,
  name              TEXT NOT NULL,
  price_minor       INTEGER NOT NULL,
  currency          TEXT NOT NULL CHECK (currency IN ('JPY', 'USD')),
  category_id       TEXT NOT NULL REFERENCES categories(id),
  next_billing_date TEXT NOT NULL,
  free_trial_days   INTEGER NOT NULL DEFAULT 0,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL
);

CREATE INDEX idx_subscriptions_created_at ON subscriptions(created_at);
CREATE INDEX idx_subscriptions_next_billing_date ON subscriptions(next_billing_date);
```

- [ ] プリセットカテゴリを投入するマイグレーション（またはAPI側で起動時に補完）
- [ ] ローカル適用: `pnpm wrangler d1 migrations apply v-subsc-db --local`
- [ ] リモート適用: `pnpm wrangler d1 migrations apply v-subsc-db --remote`

### 認証を見据えた設計メモ

このフェーズではユーザーの概念がないため `user_id` カラムは**作らない**。ただし認証導入時は
`users` テーブル追加 + `subscriptions.user_id` / `categories.user_id` の追加マイグレーションで対応する想定とし、
**SQLは `src/worker/db/*.ts` に閉じる**。UI・APIハンドラにSQLを散らさないことで、その変更が1レイヤーで済む。

### 完了条件

- ローカル・リモート双方でマイグレーションが適用済み
- `pnpm wrangler d1 execute v-subsc-db --local --command "SELECT * FROM categories"` でプリセットが確認できる
- `pnpm check` が通る

---

## 10. M6 — Hono CRUD API

**目的**: ブラウザ → Hono API → D1 のデータフローを成立させる。フロントはまだ差し替えない。

### 作業

- [ ] 依存追加: `pnpm add @hono/zod-validator`
- [ ] `src/worker/index.ts` はルート登録のみに保ち、実処理を `src/worker/routes/` へ分割
- [ ] `src/worker/db/subscriptionQueries.ts` / `categoryQueries.ts`: D1アクセスを集約
  - すべて `c.env.DB.prepare(...).bind(...)` のプレースホルダ束縛を使い、SQL文字列連結はしない
  - snake_case（DB）⇄ camelCase（アプリ）の変換はこの層で行う
- [ ] `zValidator("json", schema)` / `zValidator("param", schema)` でサーバー側検証（`src/shared/schema/` のスキーマを再利用）
- [ ] エラーレスポンス形式を統一

### エンドポイント

| メソッド | パス | 内容 | 成功時 |
|---|---|---|---|
| GET | `/api/subscriptions` | 一覧取得（`?sort=created` / `?sort=billing`） | 200 |
| POST | `/api/subscriptions` | 新規作成 | 201 |
| PATCH | `/api/subscriptions/:id` | 更新 | 200 |
| DELETE | `/api/subscriptions/:id` | 削除 | 204 |
| GET | `/api/categories` | カテゴリ一覧 | 200 |
| POST | `/api/categories` | カテゴリ追加 | 201 |

エラー形式（統一）:

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "...", "details": [] } }
```

- 検証失敗 → 400 `VALIDATION_ERROR`
- 対象なし → 404 `NOT_FOUND`
- カテゴリ名重複 → 409 `CONFLICT`
- 想定外 → 500 `INTERNAL_ERROR`（詳細はレスポンスに出さずログへ）

### 完了条件

- `pnpm dev` 起動中に curl で6エンドポイントすべてが期待どおり動く
- 不正な入力（料金が負、通貨が不正、日付形式違反）が400で弾かれる
- 存在しないIDへのPATCH/DELETEが404を返す
- `pnpm check` が通る

---

## 11. M7 — データ層のAPI差し替え

**目的**: UIコンポーネントを変更せずに保存先をD1へ移す。M1の設計が正しかったかの検証でもある。

### 作業

- [ ] `src/app/data/apiRepository.ts`: `fetch` でAPIを呼ぶリポジトリ実装（インターフェースはM1と同一）
  - レスポンスをZodで検証してから返す
  - HTTPエラーをアプリ内エラー型へ変換
- [ ] `src/app/data/index.ts` の切り替えを1行で行えるようにする（環境変数 `VITE_DATA_SOURCE` で `local` / `api` を選べるようにしておくとロールバックしやすい）
- [ ] 一覧のソートをサーバー側パラメータに寄せるか、クライアント側で維持するかを決めて統一する
- [ ] 通信中のローディング表示と失敗時のエラー表示を `useSubscriptions` に追加
- [ ] （任意）既存 `localStorage` データをAPIへ流し込む1回限りの移行ボタン

### 完了条件

- **UIコンポーネント（`features/` 配下のtsx）に差し替え起因の変更がほぼ入っていない**
  - 入ってしまった場合はM1の抽象が不足していたということなので、その差分を記録して抽象側へ寄せる
- M4の完了条件10項目が、D1バックエンドで再度すべて満たされる
- DevToolsのNetworkタブで `/api/` 越しに読み書きされていることを確認できる

---

## 12. M8 — 品質仕上げとデプロイ確認

**目的**: 認証を載せられる状態まで固める。

### 作業

- [ ] エラーハンドリングの通し確認（API停止時、ネットワーク断、不正レスポンス）
- [ ] ローディング/空状態/エラー状態のUI整備
- [ ] アクセシビリティ最低限: モーダルのフォーカス管理、フォームのラベル紐付け、アイコンボタンの `aria-label`
- [ ] レスポンシブ確認（表が狭幅で破綻しないこと）
- [ ] `pnpm lint` / `pnpm build` / `pnpm check` をすべて通す
- [ ] `pnpm deploy` で本番デプロイし、リモートD1に対して主要操作を確認
- [ ] `docs/mvp-spec.md` の §12・§13 と実装のズレを反映（localStorage前提の記述、対象外リストの更新）
- [ ] 次フェーズ（認証）の前提整理を追記: 認証方式の候補、`user_id` 追加マイグレーション方針、既存データの扱い

### 完了条件

- 本番URLでCRUD一連が動作する
- 3つのチェックコマンドがすべてグリーン
- 認証導入の着手点が文書化されている

---

## 13. 未決事項（着手前に決める）

| # | 論点 | 選択肢 | 推奨 | 決定期限 |
|---|---|---|---|---|
| 1 | スタイリング手法 | 素のCSS / CSS Modules / Tailwind | CSS Modules（依存を増やさず衝突も避けられる） | M2着手前 |
| 2 | アイコン | lucide-react / 自前SVG | lucide-react（仕様書のPencil/Trashにそのまま対応） | M4着手前 |
| 3 | テスト基盤 | 導入しない / Vitest | Vitest（ドメイン純関数のみでも価値が高い） | M0 |
| 4 | 状態管理 | useState+フック / 外部ライブラリ | 自前フック（MVP規模ではライブラリ不要） | M1 |
| 5 | ソートの実行場所 | クライアント / サーバー | M4はクライアント、M7でサーバー移譲を検討 | M7 |
| 6 | Zodのバージョン | v3 / v4 | v4（`@hono/zod-validator` の対応バージョンを導入時に確認） | M1 |

## 14. リスクと対策

| リスク | 影響 | 対策 |
|---|---|---|
| UIがストレージ実装に依存してしまう | M7で全面書き換えになる | M1でリポジトリ抽象を先に確定。UIからの直接import禁止をレビュー観点にする |
| 同期API前提で組んでしまう | API化時に全呼び出し箇所を修正 | localStorage実装も最初からPromiseを返す |
| USD小数の浮動小数誤差 | 合計金額がずれる | 最小通貨単位の整数（`priceMinor`）で保持 |
| `shared/` が型チェックから漏れる | 壊れたまま気づかない | M0で両tsconfigの `include` に追加 |
| D1バインディング変更後の型ずれ | `env.DB` が未定義型 | バインディング変更のたびに `pnpm cf-typegen` |
| 認証追加時のスキーマ破壊 | 移行が大掛かりに | SQLを `worker/db/` に閉じ、`user_id` 追加を1マイグレーションで済ませる |
