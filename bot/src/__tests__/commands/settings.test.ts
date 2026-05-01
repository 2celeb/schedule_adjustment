/**
 * /settings コマンドのユニットテスト
 * グループ設定画面 URL の表示を検証する
 * 要件: 8.4
 */

import { createMockInteraction } from "../helpers/discordMocks";

// guildGroupMap をモック化
jest.mock("../../services/guildGroupMap", () => ({
  getGroup: jest.fn(),
  setGroup: jest.fn(),
  removeGroup: jest.fn(),
}));

import settings from "../../commands/settings";
import { getGroup } from "../../services/guildGroupMap";

describe("/settings コマンド", () => {
  const mockGetGroup = getGroup as jest.MockedFunction<typeof getGroup>;

  beforeEach(() => {
    process.env.FRONTEND_URL = "http://localhost";
  });

  it("コマンド名が settings であること", () => {
    expect(settings.data.name).toBe("settings");
  });

  it("DM で実行した場合にエラーメッセージを返すこと", async () => {
    const interaction = createMockInteraction();
    (interaction as any).guild = null;

    await settings.execute(interaction);

    expect(interaction.reply).toHaveBeenCalledWith({
      content: "このコマンドはサーバー内でのみ使用できます。",
      ephemeral: true,
    });
  });

  it("グループが未設定の場合に案内メッセージを返すこと", async () => {
    const interaction = createMockInteraction();
    mockGetGroup.mockReturnValue(undefined);

    await settings.execute(interaction);

    expect(interaction.reply).toHaveBeenCalledWith({
      content: expect.stringContaining("/schedule"),
      ephemeral: true,
    });
  });

  it("グループが設定済みの場合に設定画面 URL を ephemeral で返すこと", async () => {
    const interaction = createMockInteraction({ guildId: "guild-100" });
    mockGetGroup.mockReturnValue({
      groupId: 1,
      shareToken: "settings-token",
    });

    await settings.execute(interaction);

    expect(interaction.reply).toHaveBeenCalledWith({
      content: expect.stringContaining("/groups/settings-token/settings"),
      ephemeral: true,
    });
  });

  it("返信が ephemeral（実行者のみに表示）であること", async () => {
    const interaction = createMockInteraction({ guildId: "guild-100" });
    mockGetGroup.mockReturnValue({
      groupId: 1,
      shareToken: "token-abc",
    });

    await settings.execute(interaction);

    const replyCall = (interaction.reply as jest.Mock).mock.calls[0][0];
    expect(replyCall.ephemeral).toBe(true);
  });
});
