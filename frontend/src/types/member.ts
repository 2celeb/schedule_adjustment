/**
 * メンバーの型定義
 *
 * API レスポンスに基づくメンバー情報の型。
 * バックエンドの memberships + users テーブルから取得されるデータに対応。
 */
export interface Member {
  /** メンバー ID（users.id） */
  id: number;
  /** 表示名（変更可能） */
  display_name: string;
  /** Discord スクリーン名（デフォルト表示名） */
  discord_screen_name: string;
  /** 役割: owner / core / sub */
  role: "owner" | "core" | "sub";
  /** Google 認証によるロック状態（🔒 付き） */
  auth_locked: boolean;
}
