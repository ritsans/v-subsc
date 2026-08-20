# Cloudflare認証からD1疎通確認までの作業記録

## 1. この文書の目的

この文書は、`v-subsc`プロジェクトでCloudflareへのログインを確認し、将来のCRUD機能で利用するCloudflare D1データベースとの疎通を確認するまでに行った作業を、初学者向けに説明するものです。

今回確認したデータの流れは、次のとおりです。

```text
ブラウザ
  ↓ HTTPリクエスト
Hono API（Cloudflare Worker）
  ↓ DB binding
Cloudflare D1
```

ただし、今回Worker本体のCloudflareへのデプロイは行っていません。リモートD1への接続とCRUD操作、ローカルWorkerからローカルD1への接続、デプロイ前のdry-runまでを確認しています。

## 2. 登場するツール

### Wrangler

Wranglerは、Cloudflare WorkersやD1をターミナルから操作するためのCloudflare公式CLIです。このプロジェクトでは、グローバルにインストールされたWranglerではなく、プロジェクトに登録されているバージョンを`pnpm exec wrangler`で呼び出しています。

### Cloudflare Workers

ブラウザから送られたHTTPリクエストを受け取るサーバー側の処理です。このプロジェクトでは、`src/worker/index.ts`にHonoを使ってAPIを定義しています。

### Hono

Cloudflare Workers上で動作する、軽量なWeb APIフレームワークです。たとえば`GET /api/health/db`のようなURLと、そのURLへアクセスされたときの処理を定義できます。

### Cloudflare D1

Cloudflareが提供するSQLiteベースのデータベースです。将来、サブスクリプション情報の追加・取得・更新・削除を保存する場所として使用します。

### binding

WorkerからD1などのCloudflareリソースへアクセスするための接続口です。今回は`DB`という名前でD1をWorkerへ接続しました。Workerのコードからは`c.env.DB`として利用できます。

## 3. Cloudflare認証の確認

### 3.1 最初の認証確認

最初に次のコマンドで、Wranglerの認証状態を確認しました。

```bash
pnpm exec wrangler whoami
```

この時点では、保存されていた認証トークンの有効期限が切れており、次の内容で失敗しました。

- 認証トークンが期限切れだった
- 非対話環境のため、トークンを自動更新できなかった
- Wranglerのログ保存先が読み取り専用で、ログファイルを書き込めなかった

ログファイルのエラーと認証エラーは別の問題です。認証を直すため、ブラウザを使うOAuthログインをやり直しました。

### 3.2 ブラウザを使ったOAuthログイン

Wranglerのログイン処理では、ターミナルに表示されたURLをブラウザで開き、Cloudflareアカウントから利用許可を与えます。

途中で、次の趣旨の確認が表示されました。

```text
Cloudflare向けにAI coding agentsを設定するため、Cloudflare Skillsをインストールしますか？ (Y/n)
```

ここでは`Y`、または初期値が`Y`なのでそのままEnterを選びました。その後、ターミナルに次の表示が出ました。

```text
Successfully logged in
```

これは、WranglerがOAuthの結果を受け取り、認証情報を保存できたことを示します。

### 3.3 ログイン後の最終確認

もう一度`whoami`を実行したところ、次の情報が表示されました。

- Cloudflareのアカウント名
- アカウントID
- Wranglerへ許可されたパーミッションスコープ

この結果から、Wranglerのログインが正常に完了したと判断しました。

> アカウントIDは設定で利用する識別子ですが、APIトークンやパスワードとは異なります。それでも、必要がない場所へむやみに掲載しない方が安全です。

## 4. Cloudflare公式のエージェント設定手順の確認

Cloudflareが公開している次の公式手順を取得し、Codex向けの設定内容を確認しました。

```text
https://developers.cloudflare.com/agent-setup/prompt.md
```

公式手順には、主に次の内容が含まれていました。

- Cloudflare Skillsのインストール
- Cloudflare API用MCPサーバーの登録
- Cloudflare Docs、Bindings、Builds、Observability用MCPサーバーの登録
- MCPからCloudflareを利用するためのOAuthログイン

このセットアップ作業は途中で会話が切り替わったため、CodexのMCPサーバー登録までは完了確認していません。その時点で`codex mcp list`を確認した結果は「MCPサーバー未登録」でした。

一方、Cloudflare SkillsについてはWranglerのログイン中にインストール確認へ`Y`を選択しています。Skillsはエージェント再起動後に読み込まれます。

## 5. D1データベースの作成

簡易CRUDの疎通先として、Cloudflare D1を採用しました。これはプロジェクトの設計資料でも、本番用の保存先として予定されているためです。

次のコマンドを実行しました。

```bash
pnpm exec wrangler d1 create v-subsc-db \
  --location=apac \
  --binding=DB \
  --update-config
```

各指定の意味は次のとおりです。

| 指定 | 意味 |
|---|---|
| `v-subsc-db` | 作成するD1データベース名 |
| `--location=apac` | 主なデータ配置先のヒントをアジア太平洋地域にする |
| `--binding=DB` | Workerから`DB`という名前で接続する |
| `--update-config` | `wrangler.json`へ接続設定を自動追加する |

コマンドは成功し、D1データベース`v-subsc-db`がAPACリージョンに作成されました。

`wrangler.json`には、次のような設定が追加されています。

```json
"d1_databases": [
  {
    "binding": "DB",
    "database_name": "v-subsc-db",
    "database_id": "51c2543d-622c-4e95-862e-bd014e8e5e3c"
  }
]
```

ここで重要なのは、コードがデータベースIDを直接使用するのではなく、`DB`というbinding名を通してD1を利用する点です。

## 6. データベース構造の作成

### 6.1 マイグレーションとは

マイグレーションは、データベースにどのテーブルやインデックスを作るかをSQLファイルとして記録する仕組みです。

手作業でテーブルを作るだけでは、開発者ごと、またはローカルとCloudflare上で構造が違ってしまう可能性があります。マイグレーションをリポジトリへ保存することで、同じ構造を繰り返し適用できます。

### 6.2 subscriptionsテーブル

`migrations/0001_create_subscriptions.sql`を作成し、将来のCRUDで利用する`subscriptions`テーブルを定義しました。

主なカラムは次のとおりです。

| カラム | 保存する内容 |
|---|---|
| `id` | サブスクリプションを一意に識別するID |
| `user_id` | 将来ユーザー認証を追加するための拡張用ID |
| `name` | サービス名 |
| `price_minor` | 最小通貨単位で表した料金 |
| `currency` | `JPY`または`USD` |
| `category_id` | カテゴリID |
| `next_billing_date` | 次回請求日 |
| `free_trial_days` | 無料期間の日数 |
| `created_at` | 作成日時 |
| `updated_at` | 更新日時 |

料金を`price_minor`という整数で保存するのは、小数の計算誤差を避けるためです。たとえばUSD 15.99は`1599`として保存する想定です。

一覧の並び替えを効率よく行えるよう、作成日時と次回請求日にインデックスも作成しています。

### 6.3 ローカルD1への適用

最初にローカル環境へマイグレーションを適用しました。

```bash
pnpm exec wrangler d1 migrations apply v-subsc-db --local
```

最初の実行は、実行環境がlocalhostで待ち受ける処理を禁止していたため、`listen EPERM`で失敗しました。必要な権限を許可したうえで同じコマンドを再実行し、正常に適用できました。

### 6.4 リモートD1への適用

次に、Cloudflare上のリモートD1へ同じマイグレーションを適用しました。

```bash
pnpm exec wrangler d1 migrations apply v-subsc-db --remote
```

結果は成功で、ローカルとCloudflare上の両方に同じ`subscriptions`テーブルが作成されました。

## 7. リモートD1でのCRUD疎通確認

CRUDは、データ操作の基本となる次の4処理の頭文字です。

| 名前 | 意味 | SQL |
|---|---|---|
| Create | 新しいデータを追加する | `INSERT` |
| Read | 保存されたデータを取得する | `SELECT` |
| Update | 保存されたデータを変更する | `UPDATE` |
| Delete | 保存されたデータを削除する | `DELETE` |

疎通確認には、通常データと区別できる固定IDを使用しました。

```text
connectivity-check-20260820
```

### 7.1 事前確認

最初に、このIDが既に使われていないことを`SELECT`で確認しました。結果は0件でした。この確認により、既存データを上書きしたり削除したりする危険を避けています。

### 7.2 CreateとRead

テスト用のサブスクリプションを1件追加し、SQLの`RETURNING`で保存結果を読み取りました。

保存された主な値は次のとおりです。

```text
name: Connectivity Check
price_minor: 100
currency: JPY
```

### 7.3 Update

同じIDのレコードを更新し、次の値に変わったことを確認しました。

```text
name: Connectivity Check Updated
price_minor: 200
```

### 7.4 Delete

テスト用レコードを削除し、最後に同じIDの件数を数えました。

```text
remaining: 0
```

このため、テスト用レコードはCloudflare D1に残っていません。Create、Read、Update、DeleteのすべてがリモートD1で成功しました。

実行結果では、CloudflareのAPACリージョンにあるSingaporeの拠点から応答したことも確認できました。

## 8. Hono APIからD1への接続確認

`src/worker/index.ts`へ、次のヘルスチェックAPIを追加しました。

```ts
app.get("/api/health/db", async (c) => {
	const result = await c.env.DB.prepare("SELECT 1 AS ok").first<{ ok: number }>();

	return c.json({ database: result?.ok === 1 ? "ok" : "error" });
});
```

`SELECT 1`は、特定の業務データを変更せず、データベースへSQLを送って応答を受け取れるか確認する簡単な方法です。

ローカル開発サーバーを起動しました。

```bash
pnpm dev --host 127.0.0.1
```

その後、次のURLへアクセスしました。

```text
http://127.0.0.1:5173/api/health/db
```

レスポンスは次のとおりでした。

```json
{"database":"ok"}
```

これにより、ローカル環境のHono APIから`DB` bindingを通してローカルD1へ接続できることを確認しました。確認後、開発サーバーは停止しています。

## 9. TypeScript型の更新

`wrangler.json`へ`DB` bindingを追加したため、次のコマンドでCloudflare環境の型定義を再生成しました。

```bash
pnpm cf-typegen
```

生成された`worker-configuration.d.ts`には、次の型が追加されています。

```ts
DB: D1Database;
```

この型があることで、TypeScriptは`c.env.DB`がD1データベースであることを理解できます。存在しないメソッドを呼ぶなどの間違いを、実行前の型チェックで発見しやすくなります。

## 10. 実行した品質チェック

### 成功したチェック

```bash
pnpm lint
pnpm build
pnpm check
```

結果は次のとおりです。

- Biomeによるlintは成功
- TypeScriptの型チェックとproduction buildは成功
- Wranglerのデプロイdry-runは成功
- dry-runでも`env.DB (v-subsc-db)`がD1 bindingとして認識された

dry-runは、実際にはデプロイせず、アップロード可能なWorkerを組み立てて設定を検査する処理です。

### Vitestについて

次のコマンドも実行しました。

```bash
pnpm exec vitest run
```

これはテストケースを実行する前に、既存のVite設定とCloudflare Viteプラグインの`resolve.external`設定が競合して失敗しました。今回追加したD1コードの型エラーやビルドエラーではありませんが、今後テスト環境の設定を直す必要があります。

### Playwrightについて

Playwrightテストは今回実行していません。現在の`tests/example.spec.ts`はこのアプリではなく、Playwright公式サイトへアクセスするボイラープレートのテストです。アプリ用のE2Eテストへ置き換えてから実行する必要があります。

## 11. 変更されたファイル

| ファイル | 変更内容 |
|---|---|
| `wrangler.json` | D1の`DB` bindingを追加 |
| `worker-configuration.d.ts` | `DB: D1Database`の型を生成 |
| `migrations/0001_create_subscriptions.sql` | subscriptionsテーブルとインデックスを定義 |
| `src/worker/index.ts` | `/api/health/db`を追加 |

作業開始前から変更されていた`docs/roadmap.md`には手を加えていません。

## 12. 現時点で完了していること

- WranglerでCloudflareへログインできる
- アカウント名、ID、パーミッションスコープを確認できる
- Cloudflare上にD1データベースが存在する
- Worker用のD1 bindingが設定されている
- ローカルとリモートD1に同じテーブルが存在する
- リモートD1でCRUD操作が成功する
- ローカルHono APIからD1へ接続できる
- production buildとデプロイdry-runが成功する

## 13. まだ実施していないこと

- Worker本体のCloudflareへのデプロイ
- 公開URLからHono APIを呼び、リモートD1へ接続するE2E確認
- `/api/subscriptions`の本格的なCRUD API実装
- ブラウザUIからAPIを呼び出す処理
- リクエストデータのZod検証
- ユーザー認証とユーザーごとのデータ分離
- Vitest設定の修正と単体テスト追加
- アプリ用Playwright E2Eテストの作成

## 14. 次に進める場合の流れ

次は、プロジェクトの実装計画に沿って次の順番で進めます。

1. フロントエンドのドメインモデルと入力検証を作る
2. localStorageを使うCRUD UIを完成させる
3. Honoに`/api/subscriptions` CRUD APIを追加する
4. API内部から`c.env.DB`を使ってD1を操作する
5. フロントエンドの保存先をlocalStorageからAPIへ切り替える
6. 自動テストを追加する
7. ローカルチェック完了後にWorkerをデプロイする
8. 公開URLからブラウザ→Hono API→リモートD1の全経路を確認する

現段階では、D1を利用するための接続基盤と、データベースが実際に読み書きできることの確認まで完了しています。
