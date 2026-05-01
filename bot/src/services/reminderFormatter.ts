/**
 * リマインドメッセージ整形サービス
 *
 * リマインドメッセージ、予定一覧メッセージ、当日通知メッセージの整形を行う。
 *
 * 要件: 6.2, 6.3, 6.5
 */

// フロントエンド URL
const FRONTEND_URL = process.env.FRONTEND_URL || "http://localhost";

/** メンバー情報 */
export interface MemberInfo {
  display_name: string;
  discord_user_id?: string | null;
  role: string;
  status?: number | null;
}

/**
 * チャンネルリマインドメッセージを整形する（1回目）
 *
 * 未入力メンバーへのメンション付きメッセージを生成する。
 *
 * @param groupName - グループ名
 * @param shareToken - 共有トークン（URL 生成用）
 * @param weekStart - 対象週の開始日（YYYY-MM-DD）
 * @param weekEnd - 対象週の終了日（YYYY-MM-DD）
 * @param unfilledDiscordUserIds - 未入力メンバーの Discord ユーザー ID
 * @param unfilledMemberNames - 未入力メンバーの表示名
 * @returns 整形されたメッセージ
 */
export function formatChannelRemind(
  groupName: string,
  shareToken: string,
  weekStart: string,
  weekEnd: string,
  unfilledDiscordUserIds: string[],
  unfilledMemberNames: string[],
): string {
  const url = `${FRONTEND_URL}/groups/${shareToken}`;

  // メンション文字列を生成
  const mentions = unfilledDiscordUserIds
    .map((id) => `<@${id}>`)
    .join(" ");

  // メンション対象がいない場合は名前のみ表示
  const memberList = unfilledMemberNames.join("、");

  const lines = [
    `📋 **${groupName}** のスケジュール入力リマインド`,
    "",
    `📅 対象期間: ${weekStart} 〜 ${weekEnd}`,
    "",
  ];

  if (mentions) {
    lines.push(`⚠️ 以下のメンバーがまだ入力していません:`);
    lines.push(mentions);
  } else {
    lines.push(`⚠️ 未入力メンバー: ${memberList}`);
  }

  lines.push("");
  lines.push(`🔗 入力はこちらから: ${url}`);

  return lines.join("\n");
}

/**
 * DM リマインドメッセージを整形する（2回目）
 *
 * 個別メンバーへの DM メッセージを生成する。
 *
 * @param displayName - メンバーの表示名
 * @param groupName - グループ名
 * @param shareToken - 共有トークン（URL 生成用）
 * @param weekStart - 対象週の開始日（YYYY-MM-DD）
 * @param weekEnd - 対象週の終了日（YYYY-MM-DD）
 * @returns 整形されたメッセージ
 */
export function formatDmRemind(
  displayName: string,
  groupName: string,
  shareToken: string,
  weekStart: string,
  weekEnd: string,
): string {
  const url = `${FRONTEND_URL}/groups/${shareToken}`;

  const lines = [
    `📋 ${displayName} さん、**${groupName}** のスケジュールがまだ入力されていません。`,
    "",
    `📅 対象期間: ${weekStart} 〜 ${weekEnd}`,
    "",
    `🔗 入力はこちらから: ${url}`,
    "",
    `※ このメッセージは自動送信されています。`,
  ];

  return lines.join("\n");
}

/**
 * 予定一覧メッセージを整形する（活動日確定時）
 *
 * 確定された活動日の一覧を表示するメッセージを生成する。
 *
 * @param groupName - グループ名
 * @param eventName - イベント名
 * @param eventDays - 確定された活動日の配列
 * @returns 整形されたメッセージ
 */
export function formatScheduleConfirmed(
  groupName: string,
  eventName: string,
  eventDays: Array<{
    date: string;
    start_time?: string | null;
    end_time?: string | null;
  }>,
): string {
  const lines = [
    `✅ **${groupName}** の活動日が確定しました！`,
    "",
  ];

  if (eventDays.length === 0) {
    lines.push("📅 今週の活動日はありません。");
  } else {
    lines.push(`📅 **${eventName}** の予定:`);
    lines.push("");

    for (const day of eventDays) {
      const timeStr =
        day.start_time && day.end_time
          ? ` (${day.start_time}〜${day.end_time})`
          : "";
      lines.push(`  • ${day.date}${timeStr}`);
    }
  }

  return lines.join("\n");
}

/**
 * 活動日当日通知メッセージを整形する
 *
 * メンションなし、ユーザー名は記載。
 * カスタムメッセージが設定されている場合はそれを使用する。
 *
 * @param groupName - グループ名
 * @param eventName - イベント名
 * @param date - 活動日（YYYY-MM-DD）
 * @param startTime - 開始時間（HH:MM）
 * @param endTime - 終了時間（HH:MM）
 * @param members - メンバー情報の配列
 * @param customMessage - カスタムメッセージ（任意）
 * @param shareToken - 共有トークン（URL 生成用）
 * @returns 整形されたメッセージ
 */
export function formatDailyNotify(
  groupName: string,
  eventName: string,
  date: string,
  startTime: string | null | undefined,
  endTime: string | null | undefined,
  members: MemberInfo[],
  customMessage?: string | null,
  shareToken?: string,
): string {
  const lines: string[] = [];

  // カスタムメッセージがある場合はそれを先頭に表示
  if (customMessage) {
    lines.push(customMessage);
    lines.push("");
  } else {
    lines.push(`🎯 **本日は ${eventName} の活動日です！**`);
    lines.push("");
  }

  // 活動時間
  if (startTime && endTime) {
    lines.push(`⏰ 時間: ${startTime} 〜 ${endTime}`);
    lines.push("");
  }

  // 参加メンバー一覧（メンションなし、名前のみ）
  const available = members.filter((m) => m.status === 1);
  const maybe = members.filter((m) => m.status === 0);
  const unavailable = members.filter((m) => m.status === -1);
  const noInput = members.filter(
    (m) => m.status === null || m.status === undefined,
  );

  if (available.length > 0) {
    lines.push(
      `✅ 参加 (${available.length}): ${available.map((m) => m.display_name).join("、")}`,
    );
  }
  if (maybe.length > 0) {
    lines.push(
      `❓ 未定 (${maybe.length}): ${maybe.map((m) => m.display_name).join("、")}`,
    );
  }
  if (unavailable.length > 0) {
    lines.push(
      `❌ 不参加 (${unavailable.length}): ${unavailable.map((m) => m.display_name).join("、")}`,
    );
  }
  if (noInput.length > 0) {
    lines.push(
      `⬜ 未入力 (${noInput.length}): ${noInput.map((m) => m.display_name).join("、")}`,
    );
  }

  // スケジュールページへのリンク
  if (shareToken) {
    const url = `${FRONTEND_URL}/groups/${shareToken}`;
    lines.push("");
    lines.push(`🔗 詳細: ${url}`);
  }

  return lines.join("\n");
}
