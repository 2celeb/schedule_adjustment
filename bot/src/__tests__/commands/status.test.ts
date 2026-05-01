/**
 * /status コマンドのユニットテスト
 * 今週の予定入力状況の表示を検証する
 * 要件: 8.3
 */

import { createMockInteraction } from "../helpers/discordMocks";

// apiClient をモック化
jest.mock("../../services/apiClient", () => ({
  getWeeklyStatus: jest.fn(),
}));

// guildGroupMap をモック化
jest.mock("../../services/guildGroupMap", () => ({
  getGroup: jest.fn(),
  setGroup: jest.fn(),
  removeGroup: jest.fn(),
}));

import status from "../../commands/status";
import * as apiClient from "../../services/apiClient";
import { getGroup } from "../../services/guildGroupMap";

describe("/status コマンド", () => {
  const mockGetGroup = getGroup as jest.MockedFunction<typeof getGroup>;
  const mockGetWeeklyStatus =
    apiClient.getWeeklyStatus as jest.MockedFunction<
      typeof apiClient.getWeeklyStatus
    >;

  it("コマンド名が status であること", () => {
    expect(status.data.name).toBe("status");
  });

  it("DM で実行した場合にエラーメッセージを返すこと", async () => {
    const interaction = createMockInteraction();
    (interaction as any).guild = null;

    await status.execute(interaction);

    expect(interaction.reply).toHaveBeenCalledWith({
      content: "このコマンドはサーバー内でのみ使用できます。",
      ephemeral: true,
    });
  });

  it("グループが未設定の場合に案内メッセージを返すこと", async () => {
    const interaction = createMockInteraction();
    mockGetGroup.mockReturnValue(undefined);

    await status.execute(interaction);

    expect(interaction.reply).toHaveBeenCalledWith({
      content: expect.stringContaining("/schedule"),
      ephemeral: true,
    });
  });

  it("入力状況を正しくフォーマットして表示すること", async () => {
    const interaction = createMockInteraction({ guildId: "guild-100" });
    mockGetGroup.mockReturnValue({ groupId: 1, shareToken: "token-1" });
    mockGetWeeklyStatus.mockResolvedValue({
      group: { id: 1, name: "テスト", share_token: "token-1" },
      week_start: "2026-05-04",
      week_end: "2026-05-10",
      members: [
        {
          user_id: 1,
          display_name: "全入力済み",
          discord_user_id: "user-1",
          role: "core",
          dates: [],
          filled_count: 7,
          total_days: 7,
        },
        {
          user_id: 2,
          display_name: "一部入力",
          discord_user_id: "user-2",
          role: "core",
          dates: [],
          filled_count: 3,
          total_days: 7,
        },
        {
          user_id: 3,
          display_name: "未入力",
          discord_user_id: "user-3",
          role: "sub",
          dates: [],
          filled_count: 0,
          total_days: 7,
        },
      ],
    });

    await status.execute(interaction);

    expect(interaction.deferReply).toHaveBeenCalled();

    const editReplyCall = (interaction.editReply as jest.Mock).mock.calls[0][0];
    const content = editReplyCall.content as string;

    // 期間が表示されること
    expect(content).toContain("2026-05-04");
    expect(content).toContain("2026-05-10");

    // 全入力済みメンバーに ✅ アイコン
    expect(content).toContain("✅ 全入力済み: 7/7日入力済み");

    // 一部入力メンバーに ⚠️ アイコン
    expect(content).toContain("⚠️ 一部入力: 3/7日入力済み");

    // 未入力メンバーに ❌ アイコン
    expect(content).toContain("❌ 未入力: 0/7日入力済み");
  });

  it("API エラー時にエラーメッセージを返すこと", async () => {
    const interaction = createMockInteraction({ guildId: "guild-100" });
    mockGetGroup.mockReturnValue({ groupId: 1, shareToken: "token-1" });
    mockGetWeeklyStatus.mockRejectedValue(new Error("API エラー"));

    await status.execute(interaction);

    expect(interaction.editReply).toHaveBeenCalledWith({
      content: expect.stringContaining("失敗しました"),
    });
  });

  it("メンバーが0人の場合でも正常に表示すること", async () => {
    const interaction = createMockInteraction({ guildId: "guild-100" });
    mockGetGroup.mockReturnValue({ groupId: 1, shareToken: "token-1" });
    mockGetWeeklyStatus.mockResolvedValue({
      group: { id: 1, name: "テスト", share_token: "token-1" },
      week_start: "2026-05-04",
      week_end: "2026-05-10",
      members: [],
    });

    await status.execute(interaction);

    const editReplyCall = (interaction.editReply as jest.Mock).mock.calls[0][0];
    const content = editReplyCall.content as string;

    // 期間ヘッダーが表示されること
    expect(content).toContain("2026-05-04");
    expect(content).toContain("2026-05-10");
  });

  it("filled_count が total_days と同じ場合に ✅ アイコンが表示されること", async () => {
    const interaction = createMockInteraction({ guildId: "guild-100" });
    mockGetGroup.mockReturnValue({ groupId: 1, shareToken: "token-1" });
    mockGetWeeklyStatus.mockResolvedValue({
      group: { id: 1, name: "テスト", share_token: "token-1" },
      week_start: "2026-05-04",
      week_end: "2026-05-10",
      members: [
        {
          user_id: 1,
          display_name: "完了メンバー",
          discord_user_id: "user-1",
          role: "core",
          dates: [],
          filled_count: 5,
          total_days: 5,
        },
      ],
    });

    await status.execute(interaction);

    const editReplyCall = (interaction.editReply as jest.Mock).mock.calls[0][0];
    expect(editReplyCall.content).toContain("✅ 完了メンバー: 5/5日入力済み");
  });
});
