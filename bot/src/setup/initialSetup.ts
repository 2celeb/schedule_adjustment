import {
  ChatInputCommandInteraction,
  GuildMember,
} from "discord.js";
import * as apiClient from "../services/apiClient.js";
import { setGroup } from "../services/guildGroupMap.js";
import type { SyncMemberEntry } from "../types.js";

// フロントエンド URL（環境変数から取得）
const FRONTEND_URL = process.env.FRONTEND_URL || "http://localhost";

// メンバー上限数
const MAX_MEMBERS = 20;

// 初回設定フローの結果
export interface SetupResult {
  success: boolean;
  groupId?: number;
  shareToken?: string;
  error?: string;
}

// /schedule コマンド初回実行時の設定フローを管理する
// 処理フロー:
//   1. 初回設定開始メッセージを表示（ephemeral）
//   2. Discord OAuth 認証の案内 URL を表示
//   3. Server Members Intent でメンバーリスト自動取得
//   4. Rails 内部 API でグループ作成
//   5. Rails 内部 API でメンバー同期
//   6. guildGroupMap にキャッシュ登録
//   7. 設定完了メッセージを表示
//
// 要件: 2.1, 2.2, 8.1, 8.5
export async function runInitialSetup(
  interaction: ChatInputCommandInteraction
): Promise<SetupResult> {
  const guild = interaction.guild;
  if (!guild) {
    return { success: false, error: "サーバー情報を取得できません。" };
  }

  const guildId = guild.id;
  const guildName = guild.name;

  // 1. 初回設定開始メッセージを表示
  const oauthUrl = `${FRONTEND_URL}/oauth/discord?guild_id=${guildId}`;

  await interaction.editReply({
    content:
      `🔧 初回設定を開始します...\n\n` +
      `📎 Owner 認証が必要な場合は以下の URL から Discord 認証を行ってください:\n${oauthUrl}`,
  });

  // 2. Server Members Intent でメンバーリスト自動取得
  let fetchedMembers: GuildMember[] = [];
  let memberFetchFailed = false;

  try {
    const members = await guild.members.fetch();
    fetchedMembers = Array.from(members.values());
  } catch (error) {
    console.error("[初回設定] メンバー取得失敗:", error);
    memberFetchFailed = true;
  }

  // 3. Rails 内部 API でグループ作成
  const ownerDisplayName =
    interaction.member instanceof GuildMember
      ? interaction.member.displayName
      : interaction.user.displayName || interaction.user.username;

  let group;
  try {
    const response = await apiClient.createGroup({
      guild_id: guildId,
      name: guildName,
      owner_discord_user_id: interaction.user.id,
      owner_discord_screen_name: ownerDisplayName,
      default_channel_id: interaction.channelId,
    });
    group = response.group;
  } catch (error) {
    console.error("[初回設定] グループ作成エラー:", error);
    await interaction.editReply({
      content:
        "⚠️ グループの作成に失敗しました。しばらくしてからもう一度 `/schedule` を実行してください。",
    });
    return { success: false, error: "グループ作成に失敗しました。" };
  }

  // 4. メンバー同期
  let syncedMemberCount = 0;
  let memberLimitExceeded = false;

  if (!memberFetchFailed && fetchedMembers.length > 0) {
    // Bot 自身を除外し、メンバーリストを作成
    const botUserId = interaction.client.user?.id;
    const membersToSync: SyncMemberEntry[] = fetchedMembers
      .filter((member) => {
        // Bot 自身を除外
        if (member.user.bot) return false;
        if (botUserId && member.user.id === botUserId) return false;
        // Owner は createGroup で既に登録済みなので除外
        if (member.user.id === interaction.user.id) return false;
        return true;
      })
      .map((member) => ({
        discord_user_id: member.user.id,
        discord_screen_name: member.displayName,
      }));

    // メンバー上限チェック（Owner 分の 1 を引く）
    const availableSlots = MAX_MEMBERS - 1;
    if (membersToSync.length > availableSlots) {
      memberLimitExceeded = true;
    }

    // 上限を超える場合は最初の availableSlots 名のみ同期
    const membersToSend = membersToSync.slice(0, availableSlots);

    if (membersToSend.length > 0) {
      try {
        const syncResult = await apiClient.syncMembers(
          group.id,
          membersToSend
        );
        syncedMemberCount =
          syncResult.results.added.length +
          syncResult.results.updated.length;
      } catch (error) {
        console.error("[初回設定] メンバー同期エラー:", error);
        // メンバー同期失敗はグループ作成の成功に影響しない
        memberFetchFailed = true;
      }
    }
  }

  // 5. guildGroupMap にキャッシュ登録
  setGroup(guildId, {
    groupId: group.id,
    shareToken: group.share_token,
  });

  // 6. 設定完了メッセージを表示
  const scheduleUrl = `${FRONTEND_URL}/groups/${group.share_token}`;
  // Owner を含めた総登録メンバー数
  const totalMembers = syncedMemberCount + 1;

  let completionMessage =
    `✅ 初回設定が完了しました！\n\n` +
    `📋 グループ名: ${guildName}\n` +
    `👥 メンバー: ${totalMembers}名を登録しました\n` +
    `📅 スケジュールページ: ${scheduleUrl}\n\n` +
    `⚙️ 詳細設定は \`/settings\` コマンドまたは設定画面から変更できます。`;

  // メンバー取得失敗時の追加メッセージ
  if (memberFetchFailed) {
    completionMessage +=
      `\n\n⚠️ メンバーの自動取得に失敗しました。メンバーは設定画面から手動で追加できます。`;
  }

  // メンバー上限超過時の追加メッセージ
  if (memberLimitExceeded) {
    completionMessage +=
      `\n\n⚠️ メンバー数が上限（${MAX_MEMBERS}名）を超えているため、最初の${MAX_MEMBERS}名を登録しました。`;
  }

  await interaction.editReply({
    content: completionMessage,
  });

  return {
    success: true,
    groupId: group.id,
    shareToken: group.share_token,
  };
}
