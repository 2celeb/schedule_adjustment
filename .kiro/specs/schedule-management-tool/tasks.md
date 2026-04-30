# 実装計画: スケジュール調整ツール

## 概要

小規模グループ（最大約20名）向けスケジュール調整ツールの実装計画。Discord コミュニティでの利用を前提とし、参加可否の可視化、活動日の自動・手動設定、Discord Bot および Google カレンダー連携を段階的に構築する。

技術スタック:
- バックエンド: Ruby on Rails 7.1+（API モード）+ PostgreSQL + Sidekiq + Redis
- フロントエンド: React 18+ + Vite + TypeScript + Tailwind CSS + TanStack Query
- Discord Bot: Node.js + discord.js v14+ + TypeScript
- インフラ: Docker Compose（ConoHa VPS）

## タスク

- [-] 1. プロジェクト基盤構築
  - [x] 1.1 モノレポ構成とDocker Compose開発環境のセットアップ
    - `schedule-adjustment/` 直下に `backend/`、`frontend/`、`bot/`、`nginx/`、`doc/` ディレクトリを作成
    - `docker-compose.yml`（開発用）を作成し、nginx、api、sidekiq、frontend、db（PostgreSQL 15）、redis、bot の各サービスを定義
    - Nginx のリバースプロキシ設定（`/api/*` → Rails、`/*` → React）を作成
    - _要件: 全体基盤_

  - [x] 1.2 Rails API プロジェクトの初期化
    - `backend/` に Rails 7.1+ API モードプロジェクトを作成
    - Gemfile に必要な gem を追加: `pg`、`sidekiq`、`sidekiq-cron`、`rack-attack`、`rack-cors`、`nanoid`、`rspec-rails`、`factory_bot_rails`、`rantly`（プロパティテスト用）
    - `Dockerfile` を作成
    - CORS 設定でフロントエンドドメインのみ許可
    - rack-attack によるレート制限の基本設定
    - _要件: 全体基盤_

  - [x] 1.3 データベースマイグレーションの作成
    - `users` テーブル: `discord_user_id`(UNIQUE)、`discord_screen_name`、`display_name`、`google_account_id`(UNIQUE)、`google_oauth_token`(暗号化)、`google_calendar_scope`、`auth_locked`(default:false)、`locale`(default:'ja')、`anonymized`(default:false)
    - `groups` テーブル: `name`、`event_name`、`owner_id`(FK)、`share_token`(UNIQUE/nanoid)、`timezone`(default:'Asia/Tokyo')、`default_start_time`、`default_end_time`、`threshold_n`、`threshold_target`(default:'core')、`ad_enabled`(default:true)、`locale`(default:'ja')
    - `memberships` テーブル: `user_id`(FK)、`group_id`(FK)、`role`(default:'sub')、UNIQUE(user_id, group_id)
    - `availabilities` テーブル: `user_id`(FK)、`group_id`(FK)、`date`、`status`(integer)、`comment`、`auto_synced`(default:false)、UNIQUE(user_id, group_id, date)
    - `availability_logs` テーブル: `availability_id`(FK)、`user_id`(FK)、`old_status`、`new_status`、`old_comment`、`new_comment`、`user_agent`、`ip_address`、`geo_region`
    - `event_days` テーブル: `group_id`(FK)、`date`、`start_time`、`end_time`、`auto_generated`、`confirmed`(default:false)、`confirmed_at`、UNIQUE(group_id, date)
    - `auto_schedule_rules` テーブル: `group_id`(FK)、`max_days_per_week`、`min_days_per_week`、`deprioritized_days`(integer[])、`excluded_days`(integer[])、`week_start_day`(default:1)、`confirm_days_before`(default:3)、`remind_days_before_confirm`(default:2)、`confirm_time`(default:'21:00')、`activity_notify_hours_before`(default:8)、`activity_notify_channel_id`、`activity_notify_message`
    - `sessions` テーブル: `user_id`(FK)、`token`(UNIQUE)、`expires_at`、`user_agent`、`ip_address`
    - `calendar_caches` テーブル: `user_id`(FK)、`group_id`(FK)、`date`、`has_event`(boolean)、`fetched_at`、UNIQUE(user_id, group_id, date)
    - `discord_configs` テーブル: `group_id`(FK/UNIQUE)、`guild_id`、`default_channel_id`、`remind_channel_id`
    - _要件: 全体基盤（doc/tech.md のデータベース設計セクション参照）_

  - [x] 1.4 Rails モデルの作成とバリデーション・リレーション定義
    - `User`、`Group`、`Membership`、`Availability`、`AvailabilityLog`、`EventDay`、`AutoScheduleRule`、`Session`、`CalendarCache`、`DiscordConfig` モデルを作成
    - 各モデルに `has_many`/`belongs_to` のリレーションを定義
    - バリデーション: `Availability.status` は `1, 0, -1, nil` のみ許可、`Membership.role` は `owner, core, sub` のみ許可、`Group.threshold_target` は `core, all` のみ許可
    - `User.google_oauth_token` に Rails の `encrypts` を適用
    - `Group.share_token` の自動生成（nanoid）
    - _要件: 2.6, 3.2_

  - [x] 1.5 モデルのユニットテスト作成
    - RSpec でバリデーション、リレーション、コールバックのテストを作成
    - _要件: 2.6, 3.2_

  - [x] 1.6 React + Vite フロントエンドプロジェクトの初期化
    - `frontend/` に React 18+ + TypeScript + Vite プロジェクトを作成
    - `package.json` に依存パッケージを追加: `@mui/material`、`@emotion/react`、`@emotion/styled`、`@mui/icons-material`、`tailwindcss`、`@tailwindcss/vite`、`@tanstack/react-query`、`axios`、`react-i18next`、`i18next`
    - MUI テーマ設定（カラーパレット、フォント）
    - Tailwind CSS の設定（レイアウト微調整用）
    - Axios クライアント設定（`frontend/src/api/client.ts`）: ベースURL、Cookie 送信設定
    - TanStack Query のプロバイダー設定
    - `Dockerfile` を作成
    - _要件: 全体基盤_

  - [ ] 1.7 国際化（i18n）の基盤設定
    - `frontend/src/i18n/ja.json` と `frontend/src/i18n/en.json` のリソースファイルを作成
    - `react-i18next` の初期設定
    - `frontend/src/utils/availabilitySymbols.ts` にロケール別記号マッピングを実装: ja → ○/△/×/−、en → ✓/?/✗/−
    - _要件: 4.12_

  - [ ]* 1.8 ロケール記号変換のプロパティテスト作成
    - **Property 10: ロケール記号切り替え**
    - fast-check を使用し、任意のロケール（ja/en）と status 値（1, 0, -1, null）の組み合わせで正しい記号が返されることを検証
    - **Validates: 要件 4.12**

- [ ] 2. チェックポイント - 基盤構築の確認
  - Docker Compose で全サービスが起動すること、Rails API が `/api` でレスポンスを返すこと、React アプリが表示されることを確認
  - すべてのテストが通ることを確認し、不明点があればユーザーに質問する

- [ ] 3. 認証・セッション管理の実装
  - [ ] 3.1 セッション管理の実装
    - `SessionsController` を作成: ログアウト（`DELETE /api/sessions`）
    - セッション作成ロジック: HttpOnly Secure Cookie（SameSite=Lax、有効期限30日）の発行
    - セッション検証ミドルウェア: Cookie からユーザーを特定するロジック
    - セッション有効期限の自動延長（アクセス時）
    - _要件: 1.9_

  - [ ] 3.2 ゆるい識別の認証ミドルウェア実装
    - リクエストヘッダーの `X-User-Id` でゆるい識別ユーザーを特定
    - `auth_locked=true` のユーザーに対しては Cookie セッションを要求し、ヘッダーのみの場合は 401 を返す
    - Cookie 優先 → `X-User-Id` フォールバックの2層認証ロジック
    - _要件: 1.2, 1.5, 1.9_

  - [ ]* 3.3 auth_locked ユーザーの操作拒否プロパティテスト
    - **Property 1: auth_locked ユーザーの操作拒否**
    - rspec-property（Rantly）を使用し、任意の `auth_locked=true` ユーザーが Cookie なしで参加可否変更を試みた場合に拒否されることを検証
    - **Validates: 要件 1.5**

  - [ ] 3.4 Google OAuth 認証フローの実装
    - `OAuth::GoogleController` を作成: OAuth 開始（`GET /oauth/google`）、コールバック（`GET /oauth/google/callback`）
    - Google OAuth 2.0 認証フロー: 認証コード取得 → トークン交換 → ユーザー情報取得
    - スコープ選択: メンバーは `calendar.freebusy.readonly` または `calendar.freebusy.readonly + calendar.events`、Owner は `calendar`
    - 認証成功時: `users.google_account_id` を設定、`auth_locked=true` に更新、セッション Cookie 発行
    - Google アカウント一意制約: 既に別の `google_account_id` が設定されている場合は 409 エラー
    - _要件: 1.4, 1.6, 7.1, 7.2_

  - [ ]* 3.5 Google アカウント一意制約のプロパティテスト
    - **Property 2: Google アカウント一意制約**
    - 任意の Google 連携済みユーザーに対して異なる `google_account_id` での認証が拒否されることを検証
    - **Validates: 要件 1.6**

  - [ ] 3.6 Google 連携解除の実装
    - `DELETE /api/users/:id/google_link` エンドポイントを作成
    - 解除処理: `auth_locked=false`、`google_oauth_token=null`、`google_account_id=null`、`google_calendar_scope=null` に更新
    - 該当ユーザーの `calendar_caches` レコードを全削除
    - セッションを無効化
    - _要件: 1.7, 7.11_

  - [ ]* 3.7 Google 連携解除のクリーンアッププロパティテスト
    - **Property 3: Google 連携解除のクリーンアップ（ラウンドトリップ）**
    - 任意の Google 連携済みユーザーの連携解除後に `auth_locked=false`、トークン・アカウントID が null、calendar_caches が全削除されていることを検証
    - **Validates: 要件 1.7, 7.11**

  - [ ] 3.8 Discord OAuth 認証フローの実装
    - `OAuth::DiscordController` を作成: OAuth 開始（`GET /oauth/discord`）、コールバック（`GET /oauth/discord/callback`）
    - Discord OAuth 2.0 認証フロー: Owner の Discord アカウントを確認
    - 認証成功時: `auth_locked=true` に更新、セッション Cookie 発行
    - _要件: 1.8_

  - [ ] 3.9 変更履歴記録の共通ロジック実装
    - `AvailabilityLog` の作成ロジックを `Availability` モデルのコールバックとして実装
    - リクエストから `user_agent`、`ip_address` を取得し記録
    - IP アドレスからの地域推定（GeoIP）ロジック
    - _要件: 1.10_

  - [ ]* 3.10 変更履歴記録のプロパティテスト
    - **Property 4: 変更履歴の記録（不変条件）**
    - 任意の Availability 変更操作後に `availability_logs` に対応レコードが作成され、必要なフィールドが記録されていることを検証
    - **Validates: 要件 1.10**

- [ ] 4. チェックポイント - 認証基盤の確認
  - ゆるい識別と OAuth 識別の2層認証が正しく動作すること、Google/Discord OAuth フローが完了すること、変更履歴が記録されることを確認
  - すべてのテストが通ることを確認し、不明点があればユーザーに質問する

- [ ] 5. グループ管理とメンバー登録の実装
  - [ ] 5.1 グループ CRUD API の実装
    - `Api::GroupsController` を作成
    - `GET /api/groups/:share_token`: グループ情報取得（認証不要）
    - `PATCH /api/groups/:id`: グループ設定更新（Owner のみ、Cookie 認証）
    - `POST /api/groups/:id/regenerate_token`: 共通URL再生成（Owner のみ）
    - グループ作成時に nanoid で `share_token` を自動生成
    - _要件: 1.1, 2.2, 10.7_

  - [ ] 5.2 メンバー管理 API の実装
    - `Api::MembershipsController` を作成
    - `GET /api/groups/:share_token/members`: メンバー一覧取得（認証不要）
    - `PATCH /api/memberships/:id`: メンバー役割変更（Owner のみ、`core`/`sub` の切り替え）
    - `PATCH /api/users/:id/display_name`: 表示名変更（ゆるい識別 or Cookie）
    - メンバー上限チェック: グループあたり最大20名、超過時は 422 エラー
    - _要件: 2.3, 2.4, 2.5, 2.6, 2.9_

  - [ ] 5.3 内部 API（Discord Bot → Rails）の実装
    - Bot トークン認証ミドルウェアの作成
    - `POST /api/internal/groups`: グループ初回作成（Bot トークン認証）
    - `POST /api/internal/groups/:id/sync_members`: メンバー同期（Discord メンバーリストからの一括登録・更新）
    - `GET /api/internal/groups/:id/weekly_status`: 週次入力状況取得
    - _要件: 2.1, 2.3, 8.1_

  - [ ] 5.4 権限ポリシーの実装
    - `GroupPolicy`: Owner のみグループ設定変更、URL再生成を許可
    - `AvailabilityPolicy`: auth_locked ユーザーは Cookie 必須、過去日付は Owner のみ変更可
    - `EventDayPolicy`: Owner のみ活動日の追加・変更・削除を許可
    - _要件: 1.5, 3.7, 3.8, 5.7, 5.8_

  - [ ]* 5.5 グループ管理・メンバー管理のユニットテスト
    - グループ CRUD、メンバー役割変更、メンバー上限チェック、権限ポリシーのテスト
    - _要件: 2.5, 2.6, 2.9_

- [ ] 6. 参加可否の入力・保存 API の実装
  - [ ] 6.1 参加可否 API の実装
    - `Api::AvailabilitiesController` を作成
    - `GET /api/groups/:share_token/availabilities`: 全メンバーの参加可否取得（月単位、集計データ含む）
    - `PUT /api/groups/:share_token/availabilities`: 参加可否の一括更新（upsert）
    - レスポンスに `group`、`members`、`availabilities`、`event_days`、`summary` を含める（設計ドキュメントの API レスポンス例に準拠）
    - 過去日付の変更制御: 一般メンバーは拒否、Owner は許可（履歴記録付き）
    - コメントの保存: status が × または △ の場合のみコメントを保存
    - _要件: 3.1, 3.2, 3.3, 3.4, 3.7, 3.8_

  - [ ]* 6.2 Availability 保存ラウンドトリップのプロパティテスト
    - **Property 5: Availability の保存ラウンドトリップ**
    - 任意の有効な status 値（1, 0, -1）とコメント文字列について、保存後に取得すると同じ値が返されることを検証
    - **Validates: 要件 3.2, 3.4**

  - [ ]* 6.3 過去日付の権限制御プロパティテスト
    - **Property 7: 過去日付の権限制御**
    - 任意の過去日付について、一般メンバーの変更は拒否され、Owner の変更は許可されることを検証
    - **Validates: 要件 3.7, 3.8**

  - [ ] 6.4 参加可否集計サービスの実装
    - `AvailabilityAggregator` サービスを作成
    - 日付ごとに ○/△/×/− の人数を集計
    - Threshold_N 判定: `threshold_target` に応じて Core_Member のみ or 全メンバーの×人数を対象とし、閾値以上で警告フラグを設定
    - _要件: 4.4, 4.7, 4.8_

  - [ ]* 6.5 集計の正確性プロパティテスト
    - **Property 8: 集計の正確性（不変条件）**
    - 任意の日付とメンバー集合について、ok + maybe + ng + none の合計がグループ総メンバー数と一致することを検証
    - **Validates: 要件 4.4**

  - [ ]* 6.6 閾値判定のプロパティテスト
    - **Property 9: 閾値判定**
    - 任意の threshold_n と threshold_target の設定について、×人数が閾値以上で警告フラグが true、未満で false になることを検証
    - **Validates: 要件 4.7, 4.8**

  - [ ] 6.5b グループ間コメント非公開の実装
    - 参加可否取得 API で、リクエスト元のグループ以外のコメントが返されないことを保証
    - _要件: 10.3_

  - [ ]* 6.7 グループ間コメント非公開のプロパティテスト
    - **Property 16: グループ間のコメント非公開**
    - 任意のグループ A のコメントがグループ B の API レスポンスに含まれないことを検証
    - **Validates: 要件 10.3**

- [ ] 7. チェックポイント - バックエンド API の確認
  - グループ管理、メンバー管理、参加可否の入力・取得・集計が正しく動作すること
  - すべてのテストが通ることを確認し、不明点があればユーザーに質問する

- [ ] 8. フロントエンド: メンバー選択とゆるい識別 UI の実装
  - [ ] 8.1 メンバー選択バーの実装
    - `MemberSelector.tsx`: メンバー名を横並びで表示、クリック/タップで選択
    - `MemberAvatar.tsx`: メンバー表示（🔒 アイコン付き対応）、Discord スクリーン名のホバー/タップ表示
    - `MemberRoleBadge.tsx`: Core/Sub バッジ表示
    - localStorage に `selectedUserId` を保存し、次回アクセス時に自動選択
    - 🔒 付きユーザー選択時は `GoogleLoginButton.tsx` を表示
    - _要件: 1.2, 1.3, 1.5, 2.3, 2.4_

  - [ ] 8.2 認証関連コンポーネントの実装
    - `GoogleLoginButton.tsx`: Google OAuth 認証開始ボタン
    - `LockIcon.tsx`: 🔒 アイコンコンポーネント
    - `OAuthCallbackPage.tsx`: OAuth コールバック処理ページ
    - `useCurrentUser.ts` フック: Cookie / localStorage からの現在ユーザー識別ロジック
    - _要件: 1.4, 1.5_

  - [ ] 8.3 SchedulePage（メインページ）の実装
    - `SchedulePage.tsx`: メインスケジュールページのレイアウト
    - URL パラメータから `share_token` を取得しグループ情報を読み込み
    - メンバー選択バー + Availability_Board + 広告配置のレイアウト構成
    - レスポンシブ対応（PC / スマートフォン）
    - _要件: 1.1, 4.3_

- [ ] 9. フロントエンド: Availability_Board の実装
  - [ ] 9.1 カレンダー形式の一覧表示コンポーネント
    - `AvailabilityBoard.tsx`: 全メンバーの参加可否を日付ごとにカレンダー形式で表示
    - `MonthWeekToggle.tsx`: 月単位（デフォルト）/ 週単位の切り替え
    - 月送りナビゲーション
    - Core_Member と Sub_Member を区別して表示
    - レスポンシブ対応（PC: フルテーブル、スマートフォン: スクロール対応）
    - _要件: 4.1, 4.2, 4.3, 4.9_

  - [ ] 9.2 参加可否セルと入力機能の実装
    - `AvailabilityCell.tsx`: 各セル（○/△/×/−）の表示と入力切り替え
    - 色分け表示: 緑=○、黄=△、赤=×、グレー=−
    - ロケール設定による記号切り替え（`availabilitySymbols.ts` を使用）
    - クリック/タップで status を切り替え → API に自動保存
    - `useAvailabilities.ts` フック: TanStack Query による参加可否データの取得・キャッシュ管理
    - _要件: 3.1, 3.2, 4.11, 4.12_

  - [ ] 9.3 集計表示と警告色の実装
    - `AvailabilitySummary.tsx`: 各日付の ○/△/×/− 人数を集計表示
    - 全員参加可能（○）な日を視覚的に強調表示
    - 1名のみ参加不可（×）な日を識別可能な色で表示
    - Threshold_N 以上が×の日を警告色で表示
    - _要件: 4.4, 4.5, 4.6, 4.7_

  - [ ] 9.4 コメントツールチップの実装
    - `CommentTooltip.tsx`: ×/△の日にカーソルを合わせるかタップした際にコメントをツールチップ/ポップオーバーで表示
    - コメント入力欄: ×/△設定時にコメント入力フォームを表示
    - _要件: 3.3, 3.4, 4.10_

  - [ ] 9.5 活動日マーカーの実装
    - `EventDayMarker.tsx`: 確定済み活動日を他の日と視覚的に区別して表示
    - 活動時間がデフォルトから変更されている場合は赤の！マークで強調表示
    - _要件: 5.10, 5.11_

  - [ ] 9.6 過去日付のロック表示
    - 過去の日付は一般メンバーに対して閲覧のみ（入力不可）の UI を表示
    - Owner の場合は過去日付も編集可能
    - _要件: 3.7, 3.8_

- [ ] 10. チェックポイント - フロントエンド基本機能の確認
  - メンバー選択、参加可否の入力・表示・集計、コメント表示、レスポンシブ対応が正しく動作すること
  - すべてのテストが通ることを確認し、不明点があればユーザーに質問する

- [ ] 11. Discord Bot 基盤の実装
  - [ ] 11.1 Discord Bot プロジェクトの初期化
    - `bot/` に Node.js + TypeScript プロジェクトを作成
    - `package.json` に依存パッケージを追加: `discord.js`、`axios`
    - `Dockerfile` を作成
    - `bot/src/index.ts`: エントリポイント、Bot クライアント初期化、Server Members Intent の設定
    - `bot/src/services/apiClient.ts`: Rails 内部 API クライアント（Bot トークン認証）
    - _要件: 8.1_

  - [ ] 11.2 スラッシュコマンドの実装
    - `bot/src/commands/schedule.ts`: `/schedule` コマンド — スケジュールページURL表示、初回設定未完了時は設定フロー開始
    - `bot/src/commands/status.ts`: `/status` コマンド — 今週の予定入力状況表示
    - `bot/src/commands/settings.ts`: `/settings` コマンド — グループ設定画面URL表示（Owner のみ）
    - _要件: 8.2, 8.3, 8.4_

  - [ ] 11.3 初回設定フローの実装
    - `bot/src/setup/initialSetup.ts`: `/schedule` コマンド初回実行時の設定フロー
    - Discord OAuth 認証の要求（Owner 登録）
    - Server Members Intent でメンバーリスト自動取得 → Rails 内部 API でグループ作成・メンバー同期
    - デフォルト設定の適用: グループ名=Discord サーバー名、イベント名="${グループ名}の活動"、基本活動時間=ユーザー入力、タイムゾーン=Asia/Tokyo
    - _要件: 2.1, 2.2, 8.1, 8.5_

  - [ ] 11.4 メンバー参加・退出イベントの処理
    - `bot/src/events/guildMemberAdd.ts`: メンバー参加時に Rails API でメンバー追加
    - `bot/src/events/guildMemberRemove.ts`: メンバー退出時のログ記録
    - `bot/src/events/ready.ts`: Bot 起動時の初期化処理
    - _要件: 2.1_

  - [ ]* 11.5 Discord Bot のユニットテスト
    - Jest でコマンドハンドラー、API クライアント、メッセージ整形のテスト
    - _要件: 8.2, 8.3, 8.4_

- [ ] 12. チェックポイント - Discord Bot の確認
  - Bot がサーバーに接続し、スラッシュコマンドが動作すること、初回設定フローでグループ・メンバーが登録されることを確認
  - すべてのテストが通ることを確認し、不明点があればユーザーに質問する

- [ ] 13. 活動日設定・自動確定機能の実装
  - [ ] 13.1 活動日 CRUD API の実装
    - `Api::EventDaysController` を作成
    - `GET /api/groups/:id/event_days`: 活動日一覧取得（認証不要）
    - `POST /api/groups/:id/event_days`: 活動日手動追加（Owner のみ）
    - `PATCH /api/event_days/:id`: 活動日更新 — 活動時間の個別変更（Owner のみ）
    - `DELETE /api/event_days/:id`: 活動日削除（Owner のみ）
    - Event_Day のデフォルト時間適用: `start_time`/`end_time` が null の場合はグループの `default_start_time`/`default_end_time` を使用
    - _要件: 5.7, 5.8, 5.9_

  - [ ]* 13.2 Event_Day デフォルト時間適用のプロパティテスト
    - **Property 13: Event_Day デフォルト時間適用**
    - 任意の Event_Day について、start_time/end_time が null の場合にグループデフォルト値が使用されることを検証
    - **Validates: 要件 5.9**

  - [ ] 13.3 自動確定ルール API の実装
    - `Api::AutoScheduleRulesController` を作成
    - `GET /api/groups/:id/auto_schedule_rule`: ルール取得（Owner のみ）
    - `PUT /api/groups/:id/auto_schedule_rule`: ルール更新（Owner のみ）
    - バリデーション: max_days_per_week（1〜7）、min_days_per_week（0〜max）、week_start_day（0〜6）、confirm_days_before（正の整数）
    - _要件: 5.2, 5.3, 5.4, 5.5_

  - [ ] 13.4 AutoScheduleService の実装
    - `AutoScheduleService` を作成: 自動確定ルールに基づいて活動日を決定するコアロジック
    - 当該週の参加可否データを集計し、ルールに基づいて活動日候補を選定
    - 制約充足: 週あたり活動日数が max 以下・min 以上、除外曜日は min 未達時を除き活動日にしない、優先度を下げる曜日は後回し
    - 確定日計算: `week_start_day` の `confirm_days_before` 日前
    - _要件: 5.1, 5.6_

  - [ ]* 13.5 自動スケジュールルール制約充足のプロパティテスト
    - **Property 11: 自動スケジュールルールの制約充足**
    - 任意のルールと参加可否データについて、生成された活動日が max/min 制約と除外曜日制約を満たすことを検証
    - **Validates: 要件 5.1**

  - [ ]* 13.6 確定日計算のプロパティテスト
    - **Property 12: 確定日計算**
    - 任意の week_start_day と confirm_days_before について、計算された確定日が正しいことを検証
    - **Validates: 要件 5.4**

  - [ ] 13.7 自動確定ジョブの実装
    - `AutoConfirmJob` を作成: sidekiq-cron で確定時刻に実行
    - `AutoScheduleService` を呼び出し、活動日を確定（`confirmed: true`）
    - 確定後の処理: Discord チャンネルへの予定一覧投稿（内部 API 経由）
    - 失敗時は Sidekiq リトライ（最大3回）、全失敗時は Owner に Discord 通知
    - _要件: 5.6_

  - [ ] 13.8 フロントエンド: 活動日設定 UI の実装
    - `AutoScheduleRuleForm.tsx`: 自動確定ルール設定フォーム（最大/最低活動日数、優先度を下げる曜日、除外曜日、週の始まり、確定日、確定時刻）
    - `EventTimeEditor.tsx`: 活動時間の個別編集（Owner のみ）
    - `useGroupSettings.ts` フック: グループ設定データの取得・更新
    - _要件: 5.2, 5.3, 5.9_

- [ ] 14. リマインド・通知機能の実装
  - [ ] 14.1 リマインドジョブの実装
    - `RemindJob` を作成: リマインド開始日（確定日の N 日前）に実行
    - 1回目: 設定チャンネルに未入力メンバーへのメンション付きメッセージを投稿
    - 2回目（翌日）: まだ未入力のメンバーに DM で個別通知
    - DM 送信失敗時はスキップしてログ記録、チャンネル通知は必ず実行
    - `POST /api/internal/notifications/remind` 内部 API エンドポイント
    - _要件: 6.1, 6.2, 6.3_

  - [ ] 14.2 活動日当日通知ジョブの実装
    - `DailyNotifyJob` を作成: 活動日当日の指定時間（デフォルト: 活動開始8時間前）に実行
    - 設定チャンネルに「本日活動日です」メッセージを投稿（メンションなし、ユーザー名は記載）
    - メッセージ内容は設定で変更可能
    - 投稿チャンネルは Bot および管理画面で変更可能
    - 失敗時はリトライ、通知チャンネル無効時はデフォルトチャンネルにフォールバック
    - `POST /api/internal/notifications/daily` 内部 API エンドポイント
    - _要件: 6.4, 6.5, 6.6, 6.7_

  - [ ] 14.3 Discord Bot 通知送信サービスの実装
    - `bot/src/services/notifier.ts`: チャンネル投稿、DM 送信、メンション生成のロジック
    - `bot/src/services/reminderFormatter.ts`: リマインドメッセージ、予定一覧メッセージ、当日通知メッセージの整形
    - Discord API エラーハンドリング: DM 無効ユーザーのログ記録、レート制限は discord.js に委任
    - _要件: 6.2, 6.3, 6.5_

  - [ ] 14.4 フロントエンド: 通知設定 UI の実装
    - `NotificationSettings.tsx`: リマインド・通知に関する全設定項目の変更 UI
    - リマインド開始日、確定日、確定時刻、当日通知時間、通知チャンネル、メッセージ内容の設定
    - `SettingsPage.tsx`: グループ設定ページのレイアウト（グループ基本設定 + 閾値設定 + 通知設定 + カレンダー連携設定）
    - _要件: 6.8_

- [ ] 15. チェックポイント - 活動日管理・通知の確認
  - 活動日の手動設定・自動確定、リマインド送信、当日通知が正しく動作すること
  - すべてのテストが通ることを確認し、不明点があればユーザーに質問する

- [ ] 16. Google カレンダー連携の実装
  - [ ] 16.1 FreeBusy 同期サービスの実装
    - `FreebusySyncService` を作成: Google Calendar FreeBusy API で連携済みメンバー全員分の予定有無を一括取得
    - `calendar_caches` テーブルに `has_event`（boolean のみ）を保存 — 予定のタイトル・詳細・参加者等は一切取得・保存しない
    - キャッシュ有効期限判定: `fetched_at` から15分以上経過でキャッシュ無効
    - `has_event=true` の日の Availability を自動的に × に設定（`auto_synced=true`）
    - メンバーによる手動変更（○/△への変更）を許可
    - _要件: 7.2, 7.3, 7.4, 3.5, 3.6, 10.1_

  - [ ]* 16.2 カレンダー同期による自動×設定のプロパティテスト
    - **Property 6: カレンダー同期による自動×設定**
    - 任意の `has_event=true` の日について、対応メンバーの Availability が自動的に -1 に設定され `auto_synced=true` がマークされることを検証
    - **Validates: 要件 3.5**

  - [ ]* 16.3 プライバシー制約のプロパティテスト
    - **Property 14: プライバシー制約（calendar_caches）**
    - 任意のカレンダー同期操作後、calendar_caches に保存されるデータが `has_event`（boolean）のみであることを検証
    - **Validates: 要件 7.3, 10.1**

  - [ ]* 16.4 キャッシュ有効期限判定のプロパティテスト
    - **Property 15: キャッシュ有効期限判定**
    - 任意の fetched_at について、15分以上経過でキャッシュ無効、15分未満で有効と判定されることを検証
    - **Validates: 要件 7.4**

  - [ ] 16.5 FreeBusy 取得ジョブの実装
    - `FreebusyFetchJob` を作成: ページ表示時のキャッシュ切れ検知で非同期実行
    - Google API エラー時はキャッシュを更新せず既存キャッシュを継続使用
    - トークン期限切れ時はリフレッシュトークンで再取得、失敗時はユーザーに再認証を促す
    - API レート制限時は指数バックオフでリトライ（最大3回）
    - _要件: 7.4, 7.10_

  - [ ] 16.6 カレンダー同期 API の実装
    - `Api::CalendarSyncsController` を作成
    - `POST /api/groups/:share_token/calendar_sync`: 強制同期（「今すぐ同期」ボタン）— キャッシュを無視して FreeBusy を再取得
    - _要件: 7.5_

  - [ ] 16.7 Google カレンダー書き込みサービスの実装
    - `CalendarWriteService` を作成
    - Owner のサブカレンダー自動作成: Google Calendar API の `calendars.insert` で「[グループ名] イベント」カレンダーを作成
    - 活動日確定時の予定追加: Owner のサブカレンダーに予定作成（参加/不参加メンバー一覧付き）
    - 書き込み連携メンバーの個人カレンダーに予定作成
    - _要件: 7.7, 7.8, 7.9_

  - [ ] 16.8 フロントエンド: カレンダー連携設定 UI の実装
    - `CalendarSyncSettings.tsx`: Google カレンダー連携設定（連携パターン選択: 連携なし / 予定枠のみ / 予定枠+書き込み）
    - 「今すぐ同期」ボタン
    - Google 連携解除ボタン
    - `useCalendarSync.ts` フック: カレンダー同期状態の管理
    - _要件: 7.1, 7.5, 7.6, 7.11_

- [ ] 17. チェックポイント - Google カレンダー連携の確認
  - FreeBusy 取得・キャッシュ、自動×設定、サブカレンダー作成、予定書き込みが正しく動作すること
  - すべてのテストが通ることを確認し、不明点があればユーザーに質問する

- [ ] 18. 広告モジュールの実装
  - [ ] 18.1 広告コンポーネントの実装
    - `AdBanner.tsx`: 広告バナーコンポーネント（Google AdSense 連携）
    - `AdPlacement.tsx`: 広告配置制御 — デスクトップ: ヘッダーまたはサイドバー、モバイル: フッター固定バナー
    - 入力中（Availability_Status 入力中）はポップアップ/インタースティシャル広告を表示しない制御
    - グループの `ad_enabled` 設定に応じた広告 ON/OFF 制御
    - _要件: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

- [ ] 19. データ保護・退会処理の実装
  - [ ] 19.1 退会メンバー匿名化サービスの実装
    - `MemberAnonymizer` サービスを作成
    - 退会処理: `display_name` を「退会済みメンバーX」形式に匿名化、`anonymized=true` に設定
    - 個人情報の即時削除: `google_oauth_token`、`google_account_id`、`discord_user_id` を null に設定
    - `calendar_caches` の削除
    - `availabilities` レコードは削除せず匿名化状態で無期限保持
    - _要件: 10.4, 10.5_

  - [ ] 19.2 退会メンバーの可視性制御
    - 参加可否取得 API で、一般メンバーには退会メンバーのデータを非表示
    - Owner には退会メンバーのデータを「退会済みメンバーX」として閲覧可能に
    - _要件: 10.6_

  - [ ]* 19.3 退会メンバー匿名化・可視性制御のプロパティテスト
    - **Property 17: 退会メンバーの匿名化・可視性制御**
    - 任意の退会処理されたメンバーについて、anonymized=true、display_name が匿名化形式、トークン・Discord ID が null、availabilities が保持、一般メンバーから非表示、Owner から閲覧可能であることを検証
    - **Validates: 要件 10.4, 10.5, 10.6**

- [ ] 20. フロントエンド: 設定ページの統合
  - [ ] 20.1 グループ設定ページの統合
    - `SettingsPage.tsx` に全設定コンポーネントを統合
    - `GroupSettingsForm.tsx`: グループ基本設定（グループ名、イベント名、基本活動時間、タイムゾーン、ロケール）
    - `ThresholdSettings.tsx`: 閾値設定（Threshold_N、対象: Core のみ / 全メンバー）
    - `NotificationSettings.tsx`: 通知設定（リマインド、確定、当日通知の全項目）
    - `CalendarSyncSettings.tsx`: カレンダー連携設定
    - Owner のみアクセス可能（Cookie 認証）
    - _要件: 4.8, 5.2, 5.3, 5.4, 5.5, 6.8, 7.1_

- [ ] 21. エラーハンドリングの統合
  - [ ] 21.1 バックエンド統一エラーレスポンスの実装
    - 全 API エラーを統一 JSON 形式（`{ error: { code, message, details } }`）で返す
    - HTTP ステータスコードの適切な使い分け（400/401/403/404/409/422/429/500/502）
    - 外部サービスエラー（Google API、Discord API）のハンドリング: トークン再取得、指数バックオフ、フォールバック
    - _要件: 設計ドキュメント セクション 7_

  - [ ] 21.2 フロントエンドエラーハンドリングの実装
    - TanStack Query のリトライ機構（3回）設定
    - API 通信エラー時のトースト通知
    - 401 レスポンス時の「再ログイン」ボタン表示
    - localStorage 利用不可時のインメモリ代替 + 注意メッセージ
    - ネットワークオフライン検知時の「接続を確認してください」バナー
    - _要件: 設計ドキュメント セクション 7.5_

- [ ] 22. インフラ・CI/CD の構築
  - [ ] 22.1 本番用 Docker Compose の作成
    - `docker-compose.prod.yml` を作成: Nginx（SSL終端 + 静的ファイル配信）、Rails API（Puma）、Sidekiq、Discord Bot、PostgreSQL、Redis
    - Let's Encrypt + certbot による SSL 証明書の自動取得・更新設定
    - Docker の restart policy 設定（自動復旧）
    - PostgreSQL のバックアップ設定（cron + pg_dump、7日分デイリー + 4週分ウィークリー）
    - _要件: doc/tech.md インフラセクション参照_

  - [ ] 22.2 GitHub Actions CI/CD パイプラインの構築
    - `.github/workflows/ci.yml`: テスト実行（RSpec、Vitest、Jest）、Lint（RuboCop、ESLint、Prettier）、TypeScript 型チェック、Brakeman セキュリティスキャン
    - `.github/workflows/deploy.yml`: main ブランチ push 時に SSH 経由で ConoHa VPS にデプロイ（docker compose build → up -d → db:migrate）
    - _要件: doc/tech.md CI/CD セクション参照_

- [ ] 23. 最終チェックポイント - 全体統合テスト
  - 全機能が連携して正しく動作すること（ゆるい識別 → 参加可否入力 → 集計表示 → 活動日自動確定 → Discord 通知 → Google カレンダー書き込み）
  - すべてのテストが通ることを確認し、不明点があればユーザーに質問する

## 備考

- `*` マーク付きのタスクはオプションであり、MVP 構築を優先する場合はスキップ可能
- 各タスクは要件定義書の具体的な要件番号を参照しトレーサビリティを確保
- チェックポイントでは段階的に動作確認を行い、問題があれば早期に対処
- プロパティテストは設計ドキュメントの正確性プロパティ（Property 1〜17）に対応
- ユニットテストはエッジケースやエラー条件の検証に使用し、プロパティテストと補完的に機能
