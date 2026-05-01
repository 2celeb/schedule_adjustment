/**
 * Discord 通知送信サービス
 *
 * チャンネル投稿、DM 送信、メンション生成のロジックを提供する。
 * Discord API エラーハンドリング:
 * - DM 無効ユーザーはログ記録してスキップ
 * - レート制限は discord.js に委任
 *
 * 要件: 6.2, 6.3, 6.5
 */
import {
  Client,
  TextChannel,
  DMChannel,
  ChannelType,
  DiscordAPIError,
} from "discord.js";

/** DM 送信結果 */
export interface DmSendResult {
  discordUserId: string;
  success: boolean;
  error?: string;
}

/**
 * 指定チャンネルにメッセージを投稿する
 *
 * @param client - Discord クライアント
 * @param channelId - 投稿先チャンネル ID
 * @param content - メッセージ内容
 * @returns 送信成功かどうか
 */
export async function sendChannelMessage(
  client: Client,
  channelId: string,
  content: string,
): Promise<boolean> {
  try {
    const channel = await client.channels.fetch(channelId);

    if (!channel || channel.type !== ChannelType.GuildText) {
      console.error(
        `[Notifier] チャンネルが見つからないか、テキストチャンネルではありません: ${channelId}`,
      );
      return false;
    }

    await (channel as TextChannel).send(content);
    return true;
  } catch (error) {
    if (error instanceof DiscordAPIError) {
      console.error(
        `[Notifier] チャンネル投稿失敗: channelId=${channelId}, ` +
          `code=${error.code}, message=${error.message}`,
      );
    } else {
      console.error(
        `[Notifier] チャンネル投稿エラー: channelId=${channelId}`,
        error,
      );
    }
    return false;
  }
}

/**
 * 指定ユーザーに DM を送信する
 *
 * DM 送信失敗時（DM 無効ユーザー等）はスキップしてログ記録する。
 *
 * @param client - Discord クライアント
 * @param discordUserId - 送信先 Discord ユーザー ID
 * @param content - メッセージ内容
 * @returns DM 送信結果
 */
export async function sendDm(
  client: Client,
  discordUserId: string,
  content: string,
): Promise<DmSendResult> {
  try {
    const user = await client.users.fetch(discordUserId);
    const dmChannel: DMChannel = await user.createDM();
    await dmChannel.send(content);

    return { discordUserId, success: true };
  } catch (error) {
    let errorMessage = "不明なエラー";

    if (error instanceof DiscordAPIError) {
      // 50007: Cannot send messages to this user（DM 無効）
      if (error.code === 50007) {
        errorMessage = "DM が無効なユーザーです";
      } else {
        errorMessage = `Discord API エラー: code=${error.code}, ${error.message}`;
      }
    } else if (error instanceof Error) {
      errorMessage = error.message;
    }

    console.warn(
      `[Notifier] DM 送信失敗: userId=${discordUserId}, reason=${errorMessage}`,
    );

    return { discordUserId, success: false, error: errorMessage };
  }
}

/**
 * 複数ユーザーに DM を一括送信する
 *
 * 各ユーザーへの送信は独立して行い、1件の失敗が他に影響しない。
 *
 * @param client - Discord クライアント
 * @param targets - 送信先ユーザー ID と内容のペア
 * @returns 各ユーザーの送信結果
 */
export async function sendBulkDm(
  client: Client,
  targets: Array<{ discordUserId: string; content: string }>,
): Promise<DmSendResult[]> {
  const results: DmSendResult[] = [];

  for (const target of targets) {
    const result = await sendDm(client, target.discordUserId, target.content);
    results.push(result);
  }

  return results;
}

/**
 * Discord メンション文字列を生成する
 *
 * @param discordUserIds - メンション対象の Discord ユーザー ID 配列
 * @returns メンション文字列（例: "<@123> <@456>"）
 */
export function buildMentions(discordUserIds: string[]): string {
  return discordUserIds.map((id) => `<@${id}>`).join(" ");
}

/**
 * フォールバック付きチャンネル投稿
 *
 * 指定チャンネルへの投稿が失敗した場合、フォールバックチャンネルに投稿する。
 *
 * @param client - Discord クライアント
 * @param primaryChannelId - 優先チャンネル ID
 * @param fallbackChannelId - フォールバックチャンネル ID
 * @param content - メッセージ内容
 * @returns 送信成功かどうか
 */
export async function sendWithFallback(
  client: Client,
  primaryChannelId: string,
  fallbackChannelId: string | undefined,
  content: string,
): Promise<boolean> {
  // まず優先チャンネルに投稿
  const primaryResult = await sendChannelMessage(
    client,
    primaryChannelId,
    content,
  );
  if (primaryResult) return true;

  // 失敗した場合、フォールバックチャンネルに投稿
  if (fallbackChannelId && fallbackChannelId !== primaryChannelId) {
    console.warn(
      `[Notifier] フォールバックチャンネルに投稿: ${fallbackChannelId}`,
    );
    return sendChannelMessage(client, fallbackChannelId, content);
  }

  return false;
}
