import { REST, Routes } from "discord.js";
import schedule from "./schedule.js";
import status from "./status.js";
import settings from "./settings.js";

// スラッシュコマンドを Discord API に登録するスクリプト
// npm run deploy-commands で実行する
// discord.js の REST API を使用してグローバルコマンドとして登録する

const commands = [
  schedule.data.toJSON(),
  status.data.toJSON(),
  settings.data.toJSON(),
];

const token = process.env.DISCORD_BOT_TOKEN;
const clientId = process.env.DISCORD_CLIENT_ID;

if (!token) {
  console.error(
    "[deploy] DISCORD_BOT_TOKEN が設定されていません。環境変数を確認してください。"
  );
  process.exit(1);
}

if (!clientId) {
  console.error(
    "[deploy] DISCORD_CLIENT_ID が設定されていません。環境変数を確認してください。"
  );
  process.exit(1);
}

const rest = new REST({ version: "10" }).setToken(token);

(async () => {
  try {
    console.log(
      `[deploy] ${commands.length} 個のスラッシュコマンドを登録中...`
    );

    await rest.put(Routes.applicationCommands(clientId), {
      body: commands,
    });

    console.log("[deploy] スラッシュコマンドの登録が完了しました。");
  } catch (error) {
    console.error("[deploy] スラッシュコマンドの登録に失敗しました:", error);
    process.exit(1);
  }
})();
