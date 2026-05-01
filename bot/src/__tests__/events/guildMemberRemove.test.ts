/**
 * guildMemberRemove イベントハンドラーのユニットテスト
 * メンバー退出時のログ記録を検証する
 * 要件: 2.1
 */

import { createMockGuildMember } from "../helpers/discordMocks";
import type { GuildMember, PartialGuildMember } from "discord.js";

// guildGroupMap をモック化
jest.mock("../../services/guildGroupMap", () => ({
  getGroup: jest.fn(),
  setGroup: jest.fn(),
  removeGroup: jest.fn(),
}));

import { handleGuildMemberRemove } from "../../events/guildMemberRemove";
import { getGroup } from "../../services/guildGroupMap";

describe("guildMemberRemove イベント", () => {
  const mockGetGroup = getGroup as jest.MockedFunction<typeof getGroup>;

  it("グループが設定済みの場合にログを出力すること", async () => {
    const member = createMockGuildMember({
      userId: "leaving-user",
      displayName: "退出メンバー",
      guildId: "guild-100",
    });
    mockGetGroup.mockReturnValue({ groupId: 1, shareToken: "token-1" });

    const consoleSpy = jest
      .spyOn(console, "log")
      .mockImplementation(() => {});

    await handleGuildMemberRemove(member);

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining("メンバー退出")
    );
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining("leaving-user")
    );
  });

  it("グループが未設定の場合にスキップすること", async () => {
    const member = createMockGuildMember({ guildId: "unknown-guild" });
    mockGetGroup.mockReturnValue(undefined);

    const consoleSpy = jest
      .spyOn(console, "log")
      .mockImplementation(() => {});

    await handleGuildMemberRemove(member);

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining("未設定のためスキップ")
    );
  });

  it("partial メンバー（user が null の可能性）でもクラッシュしないこと", async () => {
    const partialMember = {
      user: null,
      guild: { id: "guild-100", name: "テスト" },
    } as unknown as PartialGuildMember;
    mockGetGroup.mockReturnValue({ groupId: 1, shareToken: "token-1" });

    const consoleSpy = jest
      .spyOn(console, "log")
      .mockImplementation(() => {});

    // 例外がスローされないことを確認
    await expect(
      handleGuildMemberRemove(partialMember)
    ).resolves.toBeUndefined();

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining("メンバー退出")
    );
  });

  it("エラー発生時にクラッシュせずログ出力のみ行うこと", async () => {
    // getGroup が例外をスローするケース
    mockGetGroup.mockImplementation(() => {
      throw new Error("予期しないエラー");
    });

    const member = createMockGuildMember({ guildId: "guild-100" });

    const consoleSpy = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});

    await expect(
      handleGuildMemberRemove(member)
    ).resolves.toBeUndefined();

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining("処理エラー"),
      expect.any(Error)
    );
  });
});
