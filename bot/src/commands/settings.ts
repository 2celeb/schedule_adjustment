import { ChatInputCommandInteraction, SlashCommandBuilder } from "discord.js";
import type { BotCommand } from "../types.js";
import { getGroup } from "../services/guildGroupMap.js";

// フロントエンド URL（デフォルト: http://localhost）
const FRONTEND_URL = process.env.FRONTEND_URL || "http://localhost";

// /settings コマンド
// グループ設定画面の URL を表示する（Owner のみ）
// ephemeral: true で返信（実行者のみに表示）
// 要件: 8.4
const settings: BotCommand = {
  data: new SlashCommandBuilder()
    .setName("settings")
    .setDescription("グループ設定画面のURLを表示します"),

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

    const url = `${FRONTEND_URL}/groups/${cached.shareToken}/settings`;
    await interaction.reply({
      content: `⚙️ グループ設定画面はこちらです:\n${url}`,
      ephemeral: true,
    });
  },
};

export default settings;
