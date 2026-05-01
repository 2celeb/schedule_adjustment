import {
  ChatInputCommandInteraction,
  SlashCommandBuilder,
} from "discord.js";

// スラッシュコマンドのインターフェース定義
export interface BotCommand {
  // コマンド定義（SlashCommandBuilder）
  data: SlashCommandBuilder;
  // コマンド実行ハンドラー
  execute: (interaction: ChatInputCommandInteraction) => Promise<void>;
}

// --- API レスポンス型定義 ---

// グループ情報
export interface ApiGroup {
  id: number;
  name: string;
  event_name: string;
  owner_id: number;
  share_token: string;
  timezone: string;
  default_start_time: string | null;
  default_end_time: string | null;
  locale: string;
  created_at: string;
  updated_at: string;
}

// グループ作成レスポンス
export interface CreateGroupResponse {
  group: ApiGroup;
}

// グループ作成パラメータ
export interface CreateGroupParams {
  guild_id: string;
  name: string;
  owner_discord_user_id: string;
  owner_discord_screen_name: string;
  default_start_time?: string;
  default_end_time?: string;
  locale?: string;
  default_channel_id?: string;
}

// メンバー同期パラメータ
export interface SyncMemberEntry {
  discord_user_id: string;
  discord_screen_name: string;
  display_name?: string;
}

// メンバー同期レスポンス
export interface SyncMembersResponse {
  group_id: number;
  results: {
    added: Array<{ discord_user_id: string; user_id: number }>;
    updated: Array<{ discord_user_id: string; user_id: number }>;
    skipped: Array<{ discord_user_id: string; reason: string }>;
    errors: Array<{ discord_user_id: string | null; message: string }>;
  };
}

// 週次入力状況レスポンス
export interface WeeklyStatusResponse {
  group: {
    id: number;
    name: string;
    share_token: string;
  };
  week_start: string;
  week_end: string;
  members: WeeklyMemberStatus[];
}

// メンバーごとの週次入力状況
export interface WeeklyMemberStatus {
  user_id: number;
  display_name: string;
  discord_user_id: string;
  role: string;
  dates: Array<{
    date: string;
    status: number | null;
    filled: boolean;
  }>;
  filled_count: number;
  total_days: number;
}

// API エラーレスポンス
export interface ApiErrorResponse {
  error: {
    code: string;
    message: string;
    details?: Array<{ field: string; message: string }>;
  };
}
