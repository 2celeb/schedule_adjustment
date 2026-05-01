/**
 * guildMemberAdd イベントハンドラーのユニットテスト
 * メンバー参加時の Rails API 連携を検証する
 * 要件: 2.1
 */

import { createMockGuildMember } from "../helpers/discordMocks";

// apiClient をモック化
jest.mock("../../services/apiClient", () => ({
  syncMembers: jest.fn(),
}));

// guildGroupMap をモック化
jest.mock("../../services/guildGroupMap", () => ({
  getGroup: jest.fn(),
  setGroup: jest.fn(),
  removeGroup: jest.fn(),
}));

import { handleGuildMemberAdd } from "../../events/guildMemberAdd";
import * as apiClient from "../../services/apiClient";
import { getGroup } from "../../services/guildGroupMap";

describe("guildMemberAdd イベント", () => {
  const mockGetGroup = getGroup as jest.MockedFunction<typeof getGroup>;
  const mockSyncMembers = apiClient.syncMembers as jest.MockedFunction<
    typeof apiClient.syncMembers
  >;

  it("グループが設定済みの場合に Rails API でメンバーを登録すること", async () => {
    const member = createMockGuildMember({
      userId: "new-user-1",
      displayName: "新メンバー",
      guildId: "guild-100",
    });
    mockGetGroup.mockReturnValue({ groupId: 1, shareToken: "token-1" });
    mockSyncMembers.mockResolvedValue({
      group_id: 1,
      results: {
        added: [{ discord_user_id: "new-user-1", user_id: 10 }],
        updated: [],
        skipped: [],
        errors: [],
      },
    });

    await handleGuildMemberAdd(member);

    expect(mockSyncMembers).toHaveBeenCalledWith(1, [
      {
        discord_user_id: "new-user-1",
        discord_screen_name: "新メンバー",
      },
    ]);
  });

  it("グループが未設定の場合にスキップすること", async () => {
    const member = createMockGuildMember({ guildId: "unknown-guild" });
    mockGetGroup.mockReturnValue(undefined);

    await handleGuildMemberAdd(member);

    expect(mockSyncMembers).not.toHaveBeenCalled();
  });

  it("Bot ユーザーの場合にスキップすること", async () => {
    const member = createMockGuildMember({
      userId: "bot-user",
      isBot: true,
      guildId: "guild-100",
    });
    mockGetGroup.mockReturnValue({ groupId: 1, shareToken: "token-1" });

    await handleGuildMemberAdd(member);

    expect(mockSyncMembers).not.toHaveBeenCalled();
  });

  it("API エラー時にクラッシュせずログ出力のみ行うこと", async () => {
    const member = createMockGuildMember({
      userId: "error-user",
      guildId: "guild-100",
    });
    mockGetGroup.mockReturnValue({ groupId: 1, shareToken: "token-1" });
    mockSyncMembers.mockRejectedValue(new Error("API 接続エラー"));

    const consoleSpy = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});

    // 例外がスローされないことを確認
    await expect(handleGuildMemberAdd(member)).resolves.toBeUndefined();

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining("メンバー登録エラー"),
      expect.any(Error)
    );
  });
});
