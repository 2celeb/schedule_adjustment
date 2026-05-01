import { ActivityType, Client } from "discord.js";
import * as apiClient from "../services/apiClient.js";
import { setGroup } from "../services/guildGroupMap.js";

// Bot 起動時の初期化処理
// Bot がログインし準備完了した時に発火する
// 接続中のサーバーのグループ情報を Rails API から取得し、guildGroupMap にキャッシュを復元する
// 要件: 2.1
export async function handleReady(client: Client<true>): Promise<void> {
  try {
    console.log(`[Bot] ログイン完了: ${client.user.tag}`);
    console.log(
      `[Bot] ${client.guilds.cache.size} 個のサーバーに接続中`
    );

    // 各サーバーのグループ情報を Rails API から取得してキャッシュを復元
    for (const [guildId, guild] of client.guilds.cache) {
      try {
        const response = await apiClient.findGroupByGuildId(guildId);
        if (response) {
          setGroup(guildId, {
            groupId: response.group.id,
            shareToken: response.group.share_token,
          });
          console.log(
            `[Bot] キャッシュ復元: guild_id=${guildId} (${guild.name}) → group_id=${response.group.id}`
          );
        } else {
          console.log(
            `[Bot] グループ未登録: guild_id=${guildId} (${guild.name}) — 次回 /schedule 実行時に設定されます`
          );
        }
      } catch (error) {
        // 個別のサーバーでエラーが発生しても他のサーバーの初期化は継続
        console.error(
          `[Bot] キャッシュ復元エラー: guild_id=${guildId} (${guild.name})`,
          error
        );
      }
    }

    // Bot のステータスを設定
    client.user.setActivity("/schedule でスケジュール管理", {
      type: ActivityType.Playing,
    });

    console.log("[Bot] 初期化完了");
  } catch (error) {
    // 初期化全体のエラーハンドリング（プロセスがクラッシュしないようにする）
    console.error("[Bot] 初期化処理エラー:", error);
  }
}
