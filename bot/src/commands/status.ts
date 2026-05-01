import { ChatInputCommandInteraction, SlashCommandBuilder } from "discord.js";
import type { BotCommand, WeeklyMemberStatus } from "../types.js";
import * as apiClient from "../services/apiClient.js";
import { getGroup } from "../services/guildGroupMap.js";

// /status コマンド
// 今週の予定入力状況を表示する
// 要件: 8.3
const status: BotCommand = {
  data: new SlashCommandBuilder()
    .setName("status")
    .setDescription("今週の予定入力状況を表示します"),

  async execute(interaction: ChatInputCommandInteraction): Promise<void> {
    // guild 外（DM 等）での実行を拒否
    if (!interaction.guild) {
      await interaction.reply({
        content: "このコマンドはサーバー内でのみ使用できます。",
        ephemeral: true,
      });
      return;
    }

    const guildId = interaction.guild.id;

    // キャッシュからグループ情報を取得
    const cached = getGroup(guildId);
    if (!cached) {
      await interaction.reply({
        content:
          "⚠️ グループが未設定です。先に `/schedule` で初回設定を行ってください。",
        ephemeral: true,
      });
      return;
    }

    await interaction.deferReply();

    try {
      const data = await apiClient.getWeeklyStatus(cached.groupId);

      // メンバーごとの入力状況をフォーマット
      const memberLines = data.members.map((member: WeeklyMemberStatus) => {
        const icon = getStatusIcon(member.filled_count, member.total_days);
        return `${icon} ${member.display_name}: ${member.filled_count}/${member.total_days}日入力済み`;
      });

      const message = [
        `📊 今週の入力状況（${data.week_start} 〜 ${data.week_end}）`,
        "",
        ...memberLines,
      ].join("\n");

      await interaction.editReply({ content: message });
    } catch (error) {
      console.error("[status] 週次入力状況取得エラー:", error);
      await interaction.editReply({
        content:
          "⚠️ 入力状況の取得に失敗しました。しばらくしてからもう一度お試しください。",
      });
    }
  },
};

// 入力状況に応じたアイコンを返す
// 全日入力済み（7/7）: ✅、一部入力: ⚠️、未入力（0/7）: ❌
function getStatusIcon(filledCount: number, totalDays: number): string {
  if (filledCount >= totalDays) return "✅";
  if (filledCount === 0) return "❌";
  return "⚠️";
}

export default status;
