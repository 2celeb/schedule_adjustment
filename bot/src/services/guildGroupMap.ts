// guild_id → グループ情報のメモリキャッシュ
// Bot 再起動時にはクリアされるが、/schedule コマンド実行時に再取得される

// キャッシュに保持するグループ情報
export interface CachedGroupInfo {
  groupId: number;
  shareToken: string;
}

// メモリキャッシュ（Map）
const cache = new Map<string, CachedGroupInfo>();

// キャッシュにグループ情報を登録する
export function setGroup(guildId: string, group: CachedGroupInfo): void {
  cache.set(guildId, group);
}

// キャッシュからグループ情報を取得する
export function getGroup(guildId: string): CachedGroupInfo | undefined {
  return cache.get(guildId);
}

// キャッシュからグループ情報を削除する
export function removeGroup(guildId: string): boolean {
  return cache.delete(guildId);
}
