import {
  Client,
  Collection,
  Events,
  GatewayIntentBits,
  Interaction,
} from "discord.js";
import type { BotCommand } from "./types.js";
import schedule from "./commands/schedule.js";
import status from "./commands/status.js";
import settings from "./commands/settings.js";
import { handleReady } from "./events/ready.js";
import { handleGuildMemberAdd } from "./events/guildMemberAdd.js";
import { handleGuildMemberRemove } from "./events/guildMemberRemove.js";

// Discord Bot エントリポイント
// discord.js v14 を使用し、スラッシュコマンドのディスパッチと
// graceful shutdown を実装する

// コマンドハンドラーの基盤（コマンド名 → BotCommand のマップ）
const commands = new Collection<string, BotCommand>();

// コマンドを登録するヘルパー関数
function registerCommand(command: BotCommand): void {
  commands.set(command.data.name, command);
  console.log(`[Bot] コマンド登録: /${command.data.name}`);
}

// スラッシュコマンドの登録
registerCommand(schedule);
registerCommand(status);
registerCommand(settings);

// Discord クライアントの初期化
// GatewayIntentBits:
//   - Guilds: サーバー情報の取得
//   - GuildMembers: メンバーリストの自動取得（Server Members Intent）
//   - GuildMessages: メッセージイベントの受信
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMembers,
    GatewayIntentBits.GuildMessages,
  ],
});

// ready イベント: Bot がログインし準備完了した時に発火
// guildGroupMap のキャッシュ復元、Bot ステータス設定を行う
client.once(Events.ClientReady, handleReady);

// guildMemberAdd イベント: メンバー参加時に Rails API でメンバー追加
client.on(Events.GuildMemberAdd, handleGuildMemberAdd);

// guildMemberRemove イベント: メンバー退出時のログ記録
client.on(Events.GuildMemberRemove, handleGuildMemberRemove);

// interactionCreate イベント: スラッシュコマンドのディスパッチ
client.on(Events.InteractionCreate, async (interaction: Interaction) => {
  // スラッシュコマンド以外は無視
  if (!interaction.isChatInputCommand()) return;

  const command = commands.get(interaction.commandName);

  if (!command) {
    console.warn(
      `[Bot] 未登録のコマンド: ${interaction.commandName}`
    );
    await interaction.reply({
      content: "不明なコマンドです。",
      ephemeral: true,
    });
    return;
  }

  try {
    await command.execute(interaction);
  } catch (error) {
    console.error(
      `[Bot] コマンド実行エラー (${interaction.commandName}):`,
      error
    );

    const errorMessage =
      "コマンドの実行中にエラーが発生しました。しばらくしてからもう一度お試しください。";

    // 既に返信済みかどうかで応答方法を切り替え
    if (interaction.replied || interaction.deferred) {
      await interaction
        .followUp({ content: errorMessage, ephemeral: true })
        .catch(console.error);
    } else {
      await interaction
        .reply({ content: errorMessage, ephemeral: true })
        .catch(console.error);
    }
  }
});

// 環境変数からトークンを取得してログイン
const token = process.env.DISCORD_BOT_TOKEN;

if (!token) {
  console.error(
    "[Bot] DISCORD_BOT_TOKEN が設定されていません。環境変数を確認してください。"
  );
  process.exit(1);
}

client.login(token).catch((error) => {
  console.error("[Bot] ログインに失敗しました:", error);
  process.exit(1);
});

// Graceful Shutdown: SIGINT / SIGTERM でクリーンに終了
function shutdown(signal: string): void {
  console.log(`[Bot] ${signal} を受信しました。シャットダウンします...`);
  client.destroy();
  console.log("[Bot] Discord クライアントを切断しました。");
  process.exit(0);
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

// コマンド登録用のエクスポート（タスク 11.2 で使用）
export { commands, client };
