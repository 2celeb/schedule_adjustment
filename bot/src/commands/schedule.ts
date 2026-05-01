import { ChatInputCommandInteraction, SlashCommandBuilder } from "discord.js";
import type { BotCommand } from "../types.js";
import * as apiClient from "../services/apiClient.js";
import { setGroup, getGroup } from "../services/guildGroupMap.js";
import { runInitialSetup } from "../setup/initialSetup.js";

// フロントエンド URL（デフォルト: http://localhost）
const FRONTEND_URL = process.env.FRONTEND_URL || "http://localhost";

// /schedule コマンド
// スケジュールページの URL を表示する
// グループが未設定（初回）の場合は初回設定フロー（runInitialSetup）を開始する
// 要件: 8.2
const schedule: BotCommand = {
  data: new SlashCommandBuilder()
    .setName("schedule")
    .setDescription("スケジュールページのURLを表示します"),

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

    // 1. キャッシュにグループ情報があるか確認 → あれば URL を返信
    const cached = getGroup(guildId);
    if (cached) {
      const url = `${FRONTEND_URL}/groups/${cached.shareToken}`;
      await interaction.reply({
        content: `📅 スケジュールページはこちらです:\n${url}`,
      });
      return;
    }

    // 応答を遅延（API 通信があるため）
    await interaction.deferReply();

    // 2. Rails API でグループを検索（findGroupByGuildId）
    try {
      const existing = await apiClient.findGroupByGuildId(guildId);

      if (existing) {
        // 3. グループが存在する場合: キャッシュに登録して URL を返信
        const group = existing.group;
        setGroup(guildId, {
          groupId: group.id,
          shareToken: group.share_token,
        });

        const url = `${FRONTEND_URL}/groups/${group.share_token}`;
        await interaction.editReply({
          content: `📅 スケジュールページはこちらです:\n${url}`,
        });
        return;
      }
    } catch (error) {
      console.error("[schedule] グループ検索エラー:", error);
      // 検索エラーの場合は初回設定フローに進む
    }

    // 4. グループが存在しない場合: runInitialSetup を呼び出して初回設定フローを開始
    try {
      await runInitialSetup(interaction);
    } catch (error) {
      console.error("[schedule] 初回設定フローエラー:", error);
      await interaction.editReply({
        content:
          "⚠️ 初回設定中にエラーが発生しました。しばらくしてからもう一度 `/schedule` を実行してください。",
      });
    }
  },
};

export default schedule;
