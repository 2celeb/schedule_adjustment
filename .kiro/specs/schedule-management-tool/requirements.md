# 要件定義書

## はじめに

本ドキュメントは、小規模グループ（最大約20名）向けのスケジュール管理ツールの要件を定義する。本ツールは、グループメンバーの参加可否を可視化し、活動日の自動・手動設定、Discord および Google カレンダーとの連携を提供する。広告収入によるサービス運用を前提とし、低コストな構成を目指す。

## 用語集

- **Schedule_Management_Tool**: 本スケジュール管理ツール全体を指すシステム
- **Owner**: グループの管理者。活動日の設定やメンバー管理の権限を持つユーザー
- **Core_Member**: グループの主要メンバー。活動日の決定において優先的に考慮される
- **Sub_Member**: グループの補助メンバー。活動日の決定において補助的に考慮される
- **Availability_Status**: メンバーの参加可否状態。○（参加可能）、△（未定・条件付き）、×（参加不可）の3段階
- **Event_Day**: Owner が設定した活動日
- **Availability_Board**: メンバー全員の参加可否を一覧表示するカレンダー形式の画面
- **Auto_Schedule_Rule**: 活動日を自動設定するためのルール（例：毎週土曜日、隔週日曜日など）
- **Comment**: ユーザーが×や△の日に付与できる補足テキスト
- **Calendar_Sync**: Google カレンダーから予定の有無のみを取得する連携機能
- **Discord_Bot**: Discord サーバーと連携し通知やリマインダーを送信するボット
- **Ad_Module**: 広告を表示し運用費を賄うためのモジュール
- **Threshold_N**: Owner が設定する「参加不可人数の閾値」。この人数以上が参加不可の場合に警告表示される

## 要件

### 要件 1: ユーザー登録とグループ管理

**ユーザーストーリー:** Owner として、メンバーをグループに招待し Core_Member と Sub_Member に分類したい。これにより、活動日の決定時にメンバーの重要度を区別できる。

#### 受け入れ基準

1. WHEN Owner がメンバーを招待する, THE Schedule_Management_Tool SHALL 招待リンクまたは招待コードを生成し対象ユーザーに送信する
2. WHEN メンバーが招待を承諾する, THE Schedule_Management_Tool SHALL 該当メンバーをグループに追加し Sub_Member としてデフォルト登録する
3. WHEN Owner がメンバーの役割を変更する, THE Schedule_Management_Tool SHALL 該当メンバーを Core_Member または Sub_Member に更新する
4. THE Schedule_Management_Tool SHALL グループあたり最大20名のメンバーを管理する
5. IF グループのメンバー数が上限の20名に達している場合, THEN THE Schedule_Management_Tool SHALL 新規招待を拒否しエラーメッセージを表示する

### 要件 2: 参加可否の入力

**ユーザーストーリー:** メンバーとして、各日の参加可否を簡単に入力したい。これにより、グループ全体のスケジュール調整が円滑に進む。

#### 受け入れ基準

1. WHEN メンバーが Availability_Board を開く, THE Schedule_Management_Tool SHALL 対象期間の各日について Availability_Status の入力フォームを表示する
2. WHEN メンバーが特定の日の Availability_Status を選択する, THE Schedule_Management_Tool SHALL ○、△、×のいずれかを保存する
3. WHEN メンバーが Availability_Status を×または△に設定した日を選択する, THE Schedule_Management_Tool SHALL Comment の入力欄を表示する
4. WHEN メンバーが Comment を入力して保存する, THE Schedule_Management_Tool SHALL 該当日の Availability_Status に Comment を紐付けて保存する
5. WHEN Calendar_Sync が有効なメンバーが Availability_Board を開く, THE Schedule_Management_Tool SHALL Google カレンダーに予定が存在する日の Availability_Status を自動的に×に設定する
6. WHILE Calendar_Sync により自動設定された×の状態である, THE Schedule_Management_Tool SHALL メンバーが手動で Availability_Status を○または△に変更することを許可する

### 要件 3: 参加可否の可視化

**ユーザーストーリー:** Owner として、全メンバーの参加可否を一目で把握したい。これにより、最適な活動日を判断できる。

#### 受け入れ基準

1. THE Availability_Board SHALL 全メンバーの Availability_Status を日付ごとにカレンダー形式で一覧表示する
2. THE Availability_Board SHALL 全員が参加可能（○）な日を視覚的に強調表示する
3. THE Availability_Board SHALL 1名のみが参加不可（×）な日を識別可能な色で表示する
4. WHEN Owner が Threshold_N を設定する, THE Availability_Board SHALL Threshold_N 人以上が参加不可（×）な日を警告色で表示する
5. THE Availability_Board SHALL Core_Member と Sub_Member を区別して表示する
6. WHEN メンバーが×または△の日にカーソルを合わせるかタップする, THE Availability_Board SHALL 該当メンバーの Comment をツールチップまたはポップオーバーで表示する

### 要件 4: 活動日の設定

**ユーザーストーリー:** Owner として、活動日を自動ルールまたは手動で設定したい。これにより、定期的な活動スケジュールを効率的に管理できる。

#### 受け入れ基準

1. WHEN Owner が Auto_Schedule_Rule を設定する, THE Schedule_Management_Tool SHALL ルールに基づいて対象期間の Event_Day を自動生成する
2. THE Auto_Schedule_Rule SHALL 繰り返しパターン（毎週特定曜日、隔週特定曜日、毎月特定日）を指定可能とする
3. WHEN Owner が手動で特定の日を Event_Day に設定する, THE Schedule_Management_Tool SHALL 該当日を Event_Day として保存する
4. WHEN Owner が既存の Event_Day を削除する, THE Schedule_Management_Tool SHALL 該当日の Event_Day 設定を解除する
5. WHEN Auto_Schedule_Rule により生成された Event_Day を Owner が個別に削除する, THE Schedule_Management_Tool SHALL 該当日のみ Event_Day 設定を解除しルール自体は維持する
6. THE Availability_Board SHALL Event_Day を他の日と視覚的に区別して表示する

### 要件 5: Google カレンダー連携

**ユーザーストーリー:** メンバーとして、Google カレンダーの予定を自動的に反映させたい。これにより、手動入力の手間を省きつつプライバシーを保護できる。

#### 受け入れ基準

1. WHEN メンバーが Google カレンダー連携を有効にする, THE Calendar_Sync SHALL Google OAuth 2.0 認証フローを開始する
2. WHEN 認証が完了する, THE Calendar_Sync SHALL Google カレンダーから対象期間の予定の有無のみを取得する
3. THE Calendar_Sync SHALL 予定のタイトル、詳細、参加者などの内容を取得せず予定枠の存在のみを参照する
4. WHEN Google カレンダーの予定が更新される, THE Calendar_Sync SHALL 定期的に予定の有無を再取得し Availability_Status を更新する
5. IF Google カレンダーへの接続に失敗した場合, THEN THE Calendar_Sync SHALL エラーメッセージを表示しメンバーに手動入力を促す
6. WHEN メンバーが Google カレンダー連携を無効にする, THE Calendar_Sync SHALL 保存済みの連携データを削除し自動設定された Availability_Status をリセットする

### 要件 6: Discord 連携

**ユーザーストーリー:** Owner として、Discord を通じてメンバーにスケジュール関連の通知を送りたい。これにより、メンバーの入力漏れを防ぎ参加率を向上させる。

#### 受け入れ基準

1. WHEN Owner が Discord 連携を設定する, THE Discord_Bot SHALL 指定された Discord サーバーのチャンネルに接続する
2. WHEN 新しい Event_Day が設定される, THE Discord_Bot SHALL 対象チャンネルに活動日の通知メッセージを送信する
3. WHEN Event_Day の3日前になる, THE Discord_Bot SHALL 未入力メンバーに対してリマインダーメッセージを送信する
4. WHEN メンバーが Discord 上でコマンドを実行する, THE Discord_Bot SHALL Availability_Board へのリンクを返信する
5. IF Discord サーバーへの接続に失敗した場合, THEN THE Discord_Bot SHALL エラーログを記録し Owner にアプリ内通知を送信する

### 要件 7: 広告表示

**ユーザーストーリー:** サービス運営者として、広告を表示してサービス運用費を賄いたい。これにより、ユーザーに無料でサービスを提供し続けられる。

#### 受け入れ基準

1. THE Ad_Module SHALL Availability_Board のヘッダーまたはフッター領域にバナー広告を表示する
2. THE Ad_Module SHALL 広告表示がカレンダーの操作性を妨げない位置に配置する
3. WHILE メンバーが Availability_Status を入力中である, THE Ad_Module SHALL ポップアップ広告やインタースティシャル広告を表示しない
4. THE Ad_Module SHALL Google AdSense または同等の広告プラットフォームと連携する

### 要件 8: データ保護とプライバシー

**ユーザーストーリー:** メンバーとして、個人の予定内容が他のメンバーに公開されないことを保証してほしい。これにより、安心してサービスを利用できる。

#### 受け入れ基準

1. THE Schedule_Management_Tool SHALL Google カレンダーから取得した予定の詳細情報をサーバーに保存しない
2. THE Schedule_Management_Tool SHALL メンバーの Availability_Status と Comment のみを保存する
3. THE Schedule_Management_Tool SHALL 各メンバーの Comment を同一グループのメンバーのみに公開する
4. IF メンバーがアカウントを削除する場合, THEN THE Schedule_Management_Tool SHALL 該当メンバーの全データを30日以内に完全削除する
