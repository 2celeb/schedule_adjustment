/**
 * 参加可否データの型定義
 *
 * API レスポンスに基づく参加可否関連の型。
 * バックエンドの availabilities / event_days テーブルから取得されるデータに対応。
 *
 * 要件: 3.2, 4.1, 5.9
 */
import type { AvailabilityStatus } from "@/utils/availabilitySymbols";

/** 個別メンバーの参加可否エントリ */
export interface AvailabilityEntry {
  /** 参加可否ステータス（1=○, 0=△, -1=×, null=未入力） */
  status: AvailabilityStatus;
  /** コメント（×/△の場合に付与可能） */
  comment: string | null;
  /** Google カレンダーから自動設定されたかどうか */
  auto_synced: boolean;
}

/**
 * 参加可否マップ
 * 日付文字列 → ユーザーID文字列 → エントリ
 */
export type AvailabilitiesMap = Record<string, Record<string, AvailabilityEntry>>;

/** 活動日エントリ */
export interface EventDayEntry {
  /** 開始時間 */
  start_time: string;
  /** 終了時間 */
  end_time: string;
  /** 確定済みかどうか */
  confirmed: boolean;
  /** デフォルトから時間変更されているかどうか */
  custom_time: boolean;
}

/** 活動日マップ（日付文字列 → エントリ） */
export type EventDaysMap = Record<string, EventDayEntry>;

/** 日別集計エントリ */
export interface SummaryEntry {
  /** 参加可能（○）の人数 */
  ok: number;
  /** 未定・条件付き（△）の人数 */
  maybe: number;
  /** 参加不可（×）の人数 */
  ng: number;
  /** 未入力（−）の人数 */
  none: number;
}

/** 集計マップ（日付文字列 → エントリ） */
export type SummaryMap = Record<string, SummaryEntry>;
