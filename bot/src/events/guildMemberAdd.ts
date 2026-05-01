import { GuildMember } from "discord.js";
import * as apiClient from "../services/apiClient.js";
import { getGroup } from "../services/guildGroupMap.js";

// メンバー参加イベントハンドラー
// Discord サーバーに新しいメンバーが参加した時に発火する
// guildGroupMap からグループ情報を取得し、Rails API にメンバーを登録する
// 要件: 2.1
export async function handleGuildMemberAdd(member: GuildMember): Promise<void> {
  try {
    const guildId = member.guild.id;

    // guildGroupMap からグループ情報を取得
    const groupInfo = getGroup(guildId);
    if (!groupInfo) {
      console.log(
        `[guildMemberAdd] guild_id=${guildId} のグループが未設定のためスキップ`
      );
      return;
    }

    // Bot ユーザーの場合はスキップ
    if (member.user.bot) {
      console.log(
        `[guildMemberAdd] Bot ユーザー (${member.user.tag}) のためスキップ`
      );
      return;
    }

    // Rails API にメンバーを登録
    const result = await apiClient.syncMembers(groupInfo.groupId, [
      {
        discord_user_id: member.user.id,
        discord_screen_name: member.displayName,
      },
    ]);

    console.log(
      `[guildMemberAdd] メンバー登録完了: discord_user_id=${member.user.id}, ` +
        `discord_screen_name=${member.displayName}, ` +
        `追加=${result.results.added.length}, ` +
        `更新=${result.results.updated.length}, ` +
        `スキップ=${result.results.skipped.length}`
    );
  } catch (error) {
    // API 通信エラー時はログ出力のみ（サイレント失敗）
    console.error(
      `[guildMemberAdd] メンバー登録エラー: discord_user_id=${member.user.id}`,
      error
    );
  }
}
