/**
 * 通知受信用 HTTP サーバー
 *
 * Rails の Sidekiq ジョブから通知リクエストを受信し、
 * Discord チャンネルへの投稿や DM 送信を行う。
 *
 * エンドポイント:
 * - POST /notifications/remind — リマインド通知
 * - POST /notifications/daily — 活動日当日通知
 *
 * Bot トークン認証（Bearer）で保護する。
 */
import http from "node:http";
import type { Client } from "discord.js";
import {
  sendChannelMessage,
  sendDm,
  sendWithFallback,
  buildMentions,
} from "./notifier.js";
import {
  formatChannelRemind,
  formatDmRemind,
  formatDailyNotify,
  formatScheduleConfirmed,
} from "./reminderFormatter.js";

const INTERNAL_API_TOKEN = process.env.INTERNAL_API_TOKEN || "";
const PORT = parseInt(process.env.BOT_HTTP_PORT || "3001", 10);

/** リマインド通知ペイロード */
interface RemindPayload {
  group_id: number;
  channel_id: string;
  type: "channel_remind" | "dm_remind";
  week_start: string;
  week_end: string;
  unfilled_discord_user_ids?: string[];
  unfilled_member_names?: string[];
  dm_targets?: Array<{
    discord_user_id: string;
    display_name: string;
  }>;
  group_name: string;
  share_token: string;
}

/** 当日通知ペイロード */
interface DailyPayload {
  group_id: number;
  channel_id: string;
  type: "daily_notify";
  group_name: string;
  event_name: string;
  date: string;
  start_time: string | null;
  end_time: string | null;
  custom_message?: string | null;
  members: Array<{
    display_name: string;
    discord_user_id?: string | null;
    role: string;
    status?: number | null;
  }>;
  share_token: string;
}

/** 予定確定通知ペイロード */
interface ConfirmPayload {
  group_id: number;
  channel_id: string;
  type: "schedule_confirmed";
  group_name: string;
  event_name: string;
  event_days: Array<{
    date: string;
    start_time?: string | null;
    end_time?: string | null;
  }>;
}

/**
 * Bearer トークンを検証する
 */
function validateToken(authHeader: string | undefined): boolean {
  if (!authHeader || !INTERNAL_API_TOKEN) return false;
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) return false;
  return match[1] === INTERNAL_API_TOKEN;
}

/**
 * リクエストボディを読み取る
 */
function readBody(req: http.IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on("data", (chunk: Buffer) => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
    req.on("error", reject);
  });
}

/**
 * リマインド通知を処理する
 */
async function handleRemind(
  client: Client,
  payload: RemindPayload,
): Promise<void> {
  if (payload.type === "channel_remind") {
    // 1回目: チャンネルにメンション付きメッセージを投稿
    const message = formatChannelRemind(
      payload.group_name,
      payload.share_token,
      payload.week_start,
      payload.week_end,
      payload.unfilled_discord_user_ids || [],
      payload.unfilled_member_names || [],
    );

    const sent = await sendChannelMessage(
      client,
      payload.channel_id,
      message,
    );

    if (!sent) {
      console.error(
        `[NotificationServer] チャンネルリマインド送信失敗: group_id=${payload.group_id}`,
      );
    }
  } else if (payload.type === "dm_remind") {
    // 2回目: DM で個別通知
    const dmTargets = payload.dm_targets || [];

    for (const target of dmTargets) {
      const message = formatDmRemind(
        target.display_name,
        payload.group_name,
        payload.share_token,
        payload.week_start,
        payload.week_end,
      );

      const result = await sendDm(
        client,
        target.discord_user_id,
        message,
      );

      if (!result.success) {
        console.warn(
          `[NotificationServer] DM 送信失敗: userId=${target.discord_user_id}, ` +
            `error=${result.error}`,
        );
      }
    }

    // DM 送信後、チャンネルにも未入力メンバーの一覧を投稿（チャンネル通知は必ず実行）
    if (payload.channel_id) {
      const memberNames = dmTargets.map((t) => t.display_name);
      const channelMessage =
        `📋 **${payload.group_name}** — まだ入力していないメンバーに DM を送信しました。\n` +
        `未入力: ${memberNames.join("、")}`;

      await sendChannelMessage(client, payload.channel_id, channelMessage);
    }
  }
}

/**
 * 当日通知を処理する
 */
async function handleDaily(
  client: Client,
  payload: DailyPayload,
): Promise<void> {
  const message = formatDailyNotify(
    payload.group_name,
    payload.event_name,
    payload.date,
    payload.start_time,
    payload.end_time,
    payload.members,
    payload.custom_message,
    payload.share_token,
  );

  const sent = await sendChannelMessage(client, payload.channel_id, message);

  if (!sent) {
    console.error(
      `[NotificationServer] 当日通知送信失敗: group_id=${payload.group_id}`,
    );
  }
}

/**
 * 予定確定通知を処理する
 */
async function handleConfirm(
  client: Client,
  payload: ConfirmPayload,
): Promise<void> {
  const message = formatScheduleConfirmed(
    payload.group_name,
    payload.event_name,
    payload.event_days,
  );

  const sent = await sendChannelMessage(client, payload.channel_id, message);

  if (!sent) {
    console.error(
      `[NotificationServer] 予定確定通知送信失敗: group_id=${payload.group_id}`,
    );
  }
}

/**
 * 通知受信用 HTTP サーバーを起動する
 *
 * @param client - Discord クライアント
 * @returns HTTP サーバーインスタンス
 */
export function startNotificationServer(client: Client): http.Server {
  const server = http.createServer(async (req, res) => {
    // CORS ヘッダー（内部通信のみだが念のため）
    res.setHeader("Content-Type", "application/json");

    // Bearer トークン認証
    if (!validateToken(req.headers.authorization)) {
      res.writeHead(401);
      res.end(JSON.stringify({ error: "Unauthorized" }));
      return;
    }

    // ルーティング
    const url = req.url || "";
    const method = req.method || "";

    if (method !== "POST") {
      res.writeHead(405);
      res.end(JSON.stringify({ error: "Method Not Allowed" }));
      return;
    }

    try {
      const body = await readBody(req);
      const payload = JSON.parse(body);

      if (url === "/notifications/remind") {
        await handleRemind(client, payload as RemindPayload);
        res.writeHead(200);
        res.end(JSON.stringify({ status: "ok" }));
      } else if (url === "/notifications/daily") {
        await handleDaily(client, payload as DailyPayload);
        res.writeHead(200);
        res.end(JSON.stringify({ status: "ok" }));
      } else if (url === "/notifications/confirm") {
        await handleConfirm(client, payload as ConfirmPayload);
        res.writeHead(200);
        res.end(JSON.stringify({ status: "ok" }));
      } else {
        res.writeHead(404);
        res.end(JSON.stringify({ error: "Not Found" }));
      }
    } catch (error) {
      console.error("[NotificationServer] リクエスト処理エラー:", error);
      res.writeHead(500);
      res.end(JSON.stringify({ error: "Internal Server Error" }));
    }
  });

  server.listen(PORT, () => {
    console.log(
      `[NotificationServer] 通知受信サーバー起動: ポート ${PORT}`,
    );
  });

  return server;
}
