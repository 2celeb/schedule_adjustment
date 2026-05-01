/**
 * グループの型定義
 *
 * API レスポンスに基づくグループ情報の型。
 * バックエンドの groups テーブルから取得されるデータに対応。
 */
export interface Group {
  /** グループ ID */
  id: number;
  /** グループ名 */
  name: string;
  /** イベント名 */
  event_name: string;
  /** ロケール（ja / en） */
  locale: string;
  /** タイムゾーン */
  timezone: string;
  /** 閾値人数（null の場合は未設定） */
  threshold_n: number | null;
  /** 閾値対象（core: コアメンバーのみ / all: 全メンバー） */
  threshold_target: "core" | "all";
  /** デフォルト開始時間 */
  default_start_time: string;
  /** デフォルト終了時間 */
  default_end_time: string;
  /** 広告表示の有効/無効 */
  ad_enabled: boolean;
}
