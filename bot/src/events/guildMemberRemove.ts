import { GuildMember, PartialGuildMember } from "discord.js";
import { getGroup } from "../services/guildGroupMap.js";

// メンバー退出イベントハンドラー
// Discord サーバーからメンバーが退出した時に発火する
// 退会メンバーの匿名化処理はタスク 19 で実装するため、ここではログ記録のみ
// 要件: 2.1
export async function handleGuildMemberRemove(
  member: GuildMember | PartialGuildMember
): Promise<void> {
  try {
    const guildId = member.guild.id;

    // guildGroupMap からグループ情報を取得
    const groupInfo = getGroup(guildId);
    if (!groupInfo) {
      console.log(
        `[guildMemberRemove] guild_id=${guildId} のグループが未設定のためスキップ`
      );
      return;
    }

    // メンバーが partial の場合、member.user が null の可能性を考慮
    const discordUserId = member.user?.id ?? "不明";
    const discordScreenName =
      member.user && "displayName" in member
        ? (member as GuildMember).displayName
        : member.user?.username ?? "不明";

    console.log(
      `[guildMemberRemove] メンバー退出: ` +
        `discord_user_id=${discordUserId}, ` +
        `discord_screen_name=${discordScreenName}, ` +
        `guild_id=${guildId}, ` +
        `group_id=${groupInfo.groupId}, ` +
        `退出日時=${new Date().toISOString()}`
    );
  } catch (error) {
    // エラー時はログ出力のみ（プロセスがクラッシュしないようにする）
    console.error(
      `[guildMemberRemove] メンバー退出イベント処理エラー:`,
      error
    );
  }
}
