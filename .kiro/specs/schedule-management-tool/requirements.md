# 要件定義書

## はじめに

本ドキュメントは、小規模グループ（最大約20名）向けのスケジュール調整ツールの要件を定義する。Discord コミュニティでの利用を前提とし、メンバーの参加可否を可視化、活動日の自動・手動設定、Discord Bot および Google カレンダーとの連携を提供する。パスワード不要の「ゆるい識別方式」と OAuth 認証の2層構造を採用し、導入障壁を極力下げる。広告収入によるサービス運用を前提とし、ConoHa VPS による低コスト構成を目指す。

## 用語集

- **Schedule_Management_Tool**: 本スケジュール調整ツール全体を指すシステム
- **Owner**: グループの管理者（1グループに1名）。Discord OAuth 認証必須。活動日の確定やメンバー管理の権限を持つ
- **Core_Member**: グループの主要メンバー。Threshold_N の判定対象
- **Sub_Member**: グループの補助メンバー。Threshold_N の判定対象外（設定による）
- **Availability_Status**: メンバーの参加可否状態。○（参加可能）、△（未定・条件付き）、×（参加不可）、−（未入力）の4段階。内部は数値管理（1, 0, -1, null）
- **Event_Day**: Owner が確定した活動日。開始時間と終了時間を持つ（終日なし）
- **Availability_Board**: メンバー全員の参加可否を一覧表示するカレンダー形式の画面
- **Auto_Schedule_Rule**: 活動日を自動設定するためのルール
- **Comment**: ユーザーが×や△の日に付与できる補足テキスト
- **Calendar_Sync**: Google カレンダーから予定の有無のみを取得する連携機能
- **Discord_Bot**: Discord サーバーと連携し通知やリマインダーを送信するボット
- **Ad_Module**: 広告を表示し運用費を賄うためのモジュール
- **Threshold_N**: Owner が設定する「参加不可人数の閾値」。この人数以上が参加不可の場合に警告表示
- **ゆるい識別**: パスワード不要でユーザー名をクリックするだけの識別方式
- **OAuth 識別**: Google/Discord OAuth で認証されたユーザーの識別方式（🔒付き）

## 要件

### 要件 1: 認証・ユーザー識別（2層構造）

**ユーザーストーリー:** メンバーとして、パスワードなしで手軽にスケジュールを入力したい。Google カレンダーを連携する場合は、自分のアカウントが安全に保護されていることを保証してほしい。

#### 受け入れ基準

1. THE Schedule_Management_Tool SHALL グループのスケジュールページを1つの共通URL（nanoid ベースのランダムID）で提供する
2. WHEN Google 未連携メンバーがページにアクセスする, THE Schedule_Management_Tool SHALL メンバー名の一覧を表示し、クリック/タップで選択するだけで入力モードに切り替える（ゆるい識別）
3. THE Schedule_Management_Tool SHALL 選択されたユーザーID を localStorage に保存し、次回アクセス時に自動で同じユーザーとして開く
4. WHEN メンバーが Google カレンダー連携を行う, THE Schedule_Management_Tool SHALL そのユーザーを OAuth 識別に昇格させ、名前の横に 🔒 アイコンを表示する
5. WHEN 🔒 付きユーザーがクリックされる, THE Schedule_Management_Tool SHALL 「Google でログイン」ボタンを表示し、Google 認証成功時のみ操作を許可する
6. THE Schedule_Management_Tool SHALL 1つのユーザーに紐付く Google アカウントを1つに制限し、異なる Google アカウントでの認証を拒否する
7. WHEN メンバーが Google 連携を解除する, THE Schedule_Management_Tool SHALL Google OAuth トークンと予定枠キャッシュを削除し、ゆるい識別に戻す
8. WHEN Owner が Discord Bot を導入する, THE Schedule_Management_Tool SHALL Discord OAuth 認証を要求し、Owner を OAuth 識別（🔒付き）として登録する
9. THE Schedule_Management_Tool SHALL OAuth 識別ユーザーに HttpOnly Secure Cookie（SameSite=Lax、有効期限30日）を発行する
10. THE Schedule_Management_Tool SHALL 全ユーザーの変更操作について、User-Agent、IP ベース地域情報、変更日時、変更内容を履歴として記録する

### 要件 2: グループ管理とメンバー登録

**ユーザーストーリー:** Owner として、Discord サーバーのメンバーを自動的にグループに登録し、Core_Member と Sub_Member に分類したい。

#### 受け入れ基準

1. WHEN Owner が Discord Bot を導入し `/schedule` コマンドで初回設定を行う, THE Schedule_Management_Tool SHALL Discord サーバーのメンバーリストを Server Members Intent で自動取得しグループに登録する
2. THE Schedule_Management_Tool SHALL グループ名のデフォルトを Discord サーバー名とし、Owner が変更可能とする
3. THE Schedule_Management_Tool SHALL メンバーの表示名のデフォルトを Discord スクリーン名とし、Owner およびメンバー自身が変更可能とする
4. WHEN メンバーの表示名が変更されている場合, THE Schedule_Management_Tool SHALL Discord スクリーン名をホバー/タップで表示する
5. WHEN Owner がメンバーの役割を変更する, THE Schedule_Management_Tool SHALL 該当メンバーを Core_Member または Sub_Member に更新する
6. THE Schedule_Management_Tool SHALL グループあたり最大20名のメンバーを管理する
7. THE Schedule_Management_Tool SHALL 1ユーザーが複数グループに所属できるようにする
8. THE Schedule_Management_Tool SHALL 1ユーザーが複数グループの Owner になれるようにする
9. IF グループのメンバー数が上限の20名に達している場合, THEN THE Schedule_Management_Tool SHALL 新規登録を拒否しエラーメッセージを表示する

> **TODO**: Owner の詳細な権限一覧は要件が固まり次第定義する（Q2）
> **TODO**: 副管理者（Co-Owner）ロールの追加を将来検討する（Q2）

### 要件 3: 参加可否の入力

**ユーザーストーリー:** メンバーとして、各日の参加可否を簡単に入力したい。Google カレンダーに予定がある日は自動で×になっていてほしい。

#### 受け入れ基準

1. WHEN メンバーが Availability_Board を開く, THE Schedule_Management_Tool SHALL 対象期間の各日について Availability_Status の入力フォームを表示する
2. WHEN メンバーが特定の日の Availability_Status を選択する, THE Schedule_Management_Tool SHALL ○（1）、△（0）、×（-1）のいずれかを保存する
3. WHEN メンバーが Availability_Status を×または△に設定した日を選択する, THE Schedule_Management_Tool SHALL Comment の入力欄を表示する
4. WHEN メンバーが Comment を入力して保存する, THE Schedule_Management_Tool SHALL 該当日の Availability_Status に Comment を紐付けて保存する
5. WHEN Calendar_Sync が有効なメンバーが Availability_Board を開く, THE Schedule_Management_Tool SHALL Google カレンダーに予定が存在する日の Availability_Status を自動的に×に設定する
6. WHILE Calendar_Sync により自動設定された×の状態である, THE Schedule_Management_Tool SHALL メンバーが手動で Availability_Status を○または△に変更することを許可する
7. THE Schedule_Management_Tool SHALL 過去の日付の Availability_Status を一般メンバーに対してロック（閲覧のみ）する
8. WHEN Owner が過去の日付の Availability_Status を変更する, THE Schedule_Management_Tool SHALL 変更を許可し履歴を記録する

### 要件 4: 参加可否の可視化

**ユーザーストーリー:** Owner として、全メンバーの参加可否を一目で把握したい。全員参加可能な日や参加不可が多い日を視覚的に区別したい。

#### 受け入れ基準

1. THE Availability_Board SHALL 全メンバーの Availability_Status を日付ごとにカレンダー形式で一覧表示する
2. THE Availability_Board SHALL デフォルトで月単位表示とし、週単位への切り替えを可能とする
3. THE Availability_Board SHALL PC とスマートフォン両方の UI に対応する（レスポンシブ）
4. THE Availability_Board SHALL 各日付の左側に ○/△/×/− の人数を集計表示する
5. THE Availability_Board SHALL 全員が参加可能（○）な日を視覚的に強調表示する
6. THE Availability_Board SHALL 1名のみが参加不可（×）な日を識別可能な色で表示する
7. WHEN Owner が Threshold_N を設定する, THE Availability_Board SHALL Threshold_N 人以上が参加不可（×）な日を警告色で表示する
8. THE Schedule_Management_Tool SHALL Threshold_N の対象を「Core_Member のみ」「全メンバー」で切り替え可能とする（デフォルト: Core_Member のみ）
9. THE Availability_Board SHALL Core_Member と Sub_Member を区別して表示する
10. WHEN メンバーが×または△の日にカーソルを合わせるかタップする, THE Availability_Board SHALL 該当メンバーの Comment をツールチップまたはポップオーバーで表示する
11. THE Availability_Board SHALL Availability_Status を色分けで表示する（緑=○、黄=△、赤=×、グレー=−）
12. THE Schedule_Management_Tool SHALL ロケール設定により記号を切り替え可能とする（日本語: ○△×、英語: ✓?✗）。初期ロケールは Bot 導入者のロケールから自動設定する

### 要件 5: 活動日の設定と自動確定

**ユーザーストーリー:** Owner として、活動日を自動ルールで設定し、週ごとに自動確定させたい。確定前にメンバーへリマインドを送り、確定後は Discord と Google カレンダーに通知したい。

#### 受け入れ基準

1. WHEN Owner が Auto_Schedule_Rule を設定する, THE Schedule_Management_Tool SHALL ルールに基づいて対象期間の Event_Day を自動生成する
2. THE Auto_Schedule_Rule SHALL 以下の項目を設定可能とする:
   - 最大活動日数/週（1〜7）
   - 最低活動日数/週（0〜最大）
   - 優先度を下げる曜日（複数選択可、デフォルト: なし）
   - 除外曜日（複数選択可。最低活動日数未達の場合は活動日とする）
   - 活動日判定基準（△×がない人は活動日とする）
3. THE Schedule_Management_Tool SHALL 週の始まりを全曜日から選択可能とする（デフォルト: 月曜日）
4. THE Schedule_Management_Tool SHALL 確定日を「週の始まりのN日前」で設定可能とする（デフォルト: 3日前）
5. THE Schedule_Management_Tool SHALL 確定時刻を設定可能とする（デフォルト: 21:00）
6. WHEN 確定タイミングに達する, THE Schedule_Management_Tool SHALL Auto_Schedule_Rule に基づいて活動日を自動確定する
7. WHEN Owner が手動で特定の日を Event_Day に設定する, THE Schedule_Management_Tool SHALL 該当日を Event_Day として保存する（Owner のみ）
8. WHEN Owner が既存の Event_Day を削除または変更する, THE Schedule_Management_Tool SHALL 変更を許可する（Owner のみ）
9. THE Schedule_Management_Tool SHALL Event_Day ごとに活動時間（開始・終了）を持つ。デフォルトはグループの基本活動時間とし、Owner が日ごとに個別変更可能とする
10. WHEN Event_Day の活動時間がデフォルトから変更されている場合, THE Availability_Board SHALL 赤の！マークで強調表示する
11. THE Availability_Board SHALL Event_Day を他の日と視覚的に区別して表示する

### 要件 6: リマインドと通知

**ユーザーストーリー:** Owner として、予定未入力のメンバーにリマインドを送り、活動日当日にはメンバーに通知したい。

#### 受け入れ基準

1. THE Schedule_Management_Tool SHALL リマインド開始日を「確定日のN日前」で設定可能とする（デフォルト: 2日前）
2. WHEN リマインド開始日に達する, THE Discord_Bot SHALL 設定されたチャンネルに未入力メンバーへのメンション付きメッセージを投稿する
3. WHEN リマインド開始日の翌日にまだ未入力のメンバーがいる場合, THE Discord_Bot SHALL 該当メンバーに DM で個別通知する
4. WHEN 活動日が自動確定される, THE Discord_Bot SHALL 設定されたチャンネルに予定一覧を投稿する
5. WHEN 活動日当日の指定時間（デフォルト: 活動開始の8時間前）に達する, THE Discord_Bot SHALL 設定されたチャンネルに「本日活動日です」メッセージを投稿する（メンションなし、ユーザー名は記載）
6. THE Schedule_Management_Tool SHALL 当日通知の投稿チャンネルを Bot および管理画面で変更可能とする
7. THE Schedule_Management_Tool SHALL 当日通知のメッセージ内容を設定で変更可能とする
8. THE Schedule_Management_Tool SHALL リマインド・通知に関する全設定項目を設定画面で変更可能とする

### 要件 7: Google カレンダー連携

**ユーザーストーリー:** メンバーとして、Google カレンダーの予定を自動的に反映させたい。Owner として、確定した活動日を Google カレンダーに自動登録したい。

#### 受け入れ基準

1. WHEN メンバーが Google カレンダー連携を有効にする, THE Calendar_Sync SHALL Google OAuth 2.0 認証フローを開始し、メンバーが連携パターン（予定枠のみ / 予定枠+書き込み）を選択する
2. WHEN 認証が完了する, THE Calendar_Sync SHALL Google カレンダーから対象期間の予定の有無のみを FreeBusy API で取得する
3. THE Calendar_Sync SHALL 予定のタイトル、詳細、参加者などの内容を取得せず予定枠の存在のみを参照する
4. WHEN ユーザーがスケジュールページを開く, THE Calendar_Sync SHALL キャッシュの有効期限（15分）を確認し、期限切れの場合は Google カレンダー連携済みメンバー全員分を FreeBusy API で一括取得する
5. THE Schedule_Management_Tool SHALL 「今すぐ同期」ボタンを提供し、キャッシュを無視して強制再取得を可能とする
6. WHEN 予定がある日の Availability_Status が自動で×に設定される, THE Schedule_Management_Tool SHALL メンバーが手動で○や△に変更することを許可する
7. WHEN Owner が Google OAuth で認証する, THE Schedule_Management_Tool SHALL Owner の Google カレンダーに「[グループ名] イベント」サブカレンダーを自動作成する
8. WHEN 活動日が確定される, THE Schedule_Management_Tool SHALL Owner のサブカレンダーに予定を追加する（参加/不参加メンバー一覧付き）
9. WHEN 活動日が確定される, THE Schedule_Management_Tool SHALL 書き込み連携メンバーの個人カレンダーに予定を作成する
10. IF Google カレンダーへの接続に失敗した場合, THEN THE Calendar_Sync SHALL エラーメッセージを表示しメンバーに手動入力を促す
11. WHEN メンバーが Google カレンダー連携を解除する, THE Calendar_Sync SHALL Google OAuth トークンと予定枠キャッシュを削除し、ゆるい識別に戻す

### 要件 8: Discord 連携

**ユーザーストーリー:** Owner として、Discord Bot を通じてグループを管理し、メンバーにスケジュール関連の通知を送りたい。

#### 受け入れ基準

1. WHEN Owner が Discord Bot をサーバーに導入する, THE Discord_Bot SHALL Server Members Intent でメンバーリストを自動取得する
2. WHEN メンバーが `/schedule` コマンドを実行する, THE Discord_Bot SHALL スケジュールページのURLを返信する。初回設定が未完了の場合は設定フローを開始する
3. WHEN メンバーが `/status` コマンドを実行する, THE Discord_Bot SHALL 今週の予定入力状況を表示する
4. WHEN Owner が `/settings` コマンドを実行する, THE Discord_Bot SHALL グループ設定画面のURLを返信する
5. THE Discord_Bot SHALL 以下の基本設定を Bot 導入時にデフォルト値で設定する:
   - グループ名: Discord サーバー名
   - イベント名: "${グループ名}の活動"
   - 基本活動時間: ユーザー入力
   - タイムゾーン: Asia/Tokyo
6. IF Discord サーバーへの接続に失敗した場合, THEN THE Discord_Bot SHALL エラーログを記録し Owner にアプリ内通知を送信する

### 要件 9: 広告表示

**ユーザーストーリー:** サービス運営者として、広告を表示してサービス運用費を賄いたい。将来的にグループ単位の有料プランも導入したい。

#### 受け入れ基準

1. THE Ad_Module SHALL デスクトップではヘッダーまたはサイドバーにバナー広告を表示する
2. THE Ad_Module SHALL モバイルではフッター固定バナー広告を表示する
3. THE Ad_Module SHALL 広告表示がカレンダーの操作性を妨げない位置に配置する
4. WHILE メンバーが Availability_Status を入力中である, THE Ad_Module SHALL ポップアップ広告やインタースティシャル広告を表示しない
5. THE Ad_Module SHALL Google AdSense または同等の広告プラットフォームと連携する
6. THE Schedule_Management_Tool SHALL グループ単位で広告の ON/OFF を制御できる機能を提供する

> **TODO**: 有料プラン（グループ単位の広告非表示、月額300〜500円）の導入を将来検討する（Q13）

### 要件 10: データ保護とプライバシー

**ユーザーストーリー:** メンバーとして、個人の予定内容が他のメンバーに公開されないことを保証してほしい。退会時にはデータが適切に処理されてほしい。

#### 受け入れ基準

1. THE Schedule_Management_Tool SHALL Google カレンダーから取得した予定の詳細情報をサーバーに保存しない（予定の有無のブール値のみキャッシュ）
2. THE Schedule_Management_Tool SHALL メンバーの Availability_Status と Comment のみを保存する
3. THE Schedule_Management_Tool SHALL 各メンバーの Comment を同一グループのメンバーのみに公開する
4. IF メンバーが退会する場合, THEN THE Schedule_Management_Tool SHALL メンバー名を「退会済みメンバーA」のように匿名化し、個人情報（メールアドレス、Google OAuth トークン等）を即時削除する
5. THE Schedule_Management_Tool SHALL 退会メンバーの Availability_Status データを匿名化した状態で無期限保持する
6. THE Schedule_Management_Tool SHALL 退会メンバーの過去データを一般メンバーには非表示とし、Owner のみ閲覧可能とする
7. THE Schedule_Management_Tool SHALL Owner に共通URLの再生成（リセット）機能を提供する
