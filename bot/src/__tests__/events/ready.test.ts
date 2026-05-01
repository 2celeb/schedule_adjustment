/**
 * ready イベントハンドラーのユニットテスト
 * Bot 起動時のキャッシュ復元とステータス設定を検証する
 * 要件: 2.1
 */

import { createMockCollection } from "../helpers/discordMocks";
import type { Client, Guild } from "discord.js";
import { ActivityType } from "discord.js";

// apiClient をモック化
jest.mock("../../services/apiClient", () => ({
  findGroupByGuildId: jest.fn(),
}));

// guildGroupMap をモック化
jest.mock("../../services/guildGroupMap", () => ({
  setGroup: jest.fn(),
  getGroup: jest.fn(),
  removeGroup: jest.fn(),
}));

import { handleReady } from "../../events/ready";
import * as apiClient from "../../services/apiClient";
import { setGroup } from "../../services/guildGroupMap";

describe("ready イベント", () => {
  const mockFindGroup = apiClient.findGroupByGuildId as jest.MockedFunction<
    typeof apiClient.findGroupByGuildId
  >;
  const mockSetGroup = setGroup as jest.MockedFunction<typeof setGroup>;

  function createMockClient(
    guilds: [string, Partial<Guild>][]
  ): Client<true> {
    const guildCollection = createMockCollection(guilds);
    return {
      user: {
        tag: "TestBot#0001",
        setActivity: jest.fn(),
      },
      guilds: {
        cache: guildCollection,
      },
    } as unknown as Client<true>;
  }

  it("接続中のサーバーのグループ情報をキャッシュに復元すること", async () => {
    const client = createMockClient([
      ["guild-1", { name: "サーバー1" } as Partial<Guild>],
      ["guild-2", { name: "サーバー2" } as Partial<Guild>],
    ]);

    mockFindGroup
      .mockResolvedValueOnce({
        group: {
          id: 10,
          name: "サーバー1",
          share_token: "token-1",
          event_name: "テスト",
          owner_id: 1,
          timezone: "Asia/Tokyo",
          default_start_time: null,
          default_end_time: null,
          locale: "ja",
          created_at: "2026-01-01",
          updated_at: "2026-01-01",
        },
      })
      .mockResolvedValueOnce({
        group: {
          id: 20,
          name: "サーバー2",
          share_token: "token-2",
          event_name: "テスト",
          owner_id: 2,
          timezone: "Asia/Tokyo",
          default_start_time: null,
          default_end_time: null,
          locale: "ja",
          created_at: "2026-01-01",
          updated_at: "2026-01-01",
        },
      });

    const consoleSpy = jest
      .spyOn(console, "log")
      .mockImplementation(() => {});

    await handleReady(client);

    expect(mockSetGroup).toHaveBeenCalledWith("guild-1", {
      groupId: 10,
      shareToken: "token-1",
    });
    expect(mockSetGroup).toHaveBeenCalledWith("guild-2", {
      groupId: 20,
      shareToken: "token-2",
    });
  });

  it("未登録のサーバーはキャッシュに登録しないこと", async () => {
    const client = createMockClient([
      ["guild-new", { name: "新サーバー" } as Partial<Guild>],
    ]);

    mockFindGroup.mockResolvedValue(null);

    const consoleSpy = jest
      .spyOn(console, "log")
      .mockImplementation(() => {});

    await handleReady(client);

    expect(mockSetGroup).not.toHaveBeenCalled();
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining("グループ未登録")
    );
  });

  it("個別サーバーのエラーが他のサーバーの初期化に影響しないこと", async () => {
    const client = createMockClient([
      ["guild-err", { name: "エラーサーバー" } as Partial<Guild>],
      ["guild-ok", { name: "正常サーバー" } as Partial<Guild>],
    ]);

    mockFindGroup
      .mockRejectedValueOnce(new Error("API エラー"))
      .mockResolvedValueOnce({
        group: {
          id: 30,
          name: "正常サーバー",
          share_token: "token-ok",
          event_name: "テスト",
          owner_id: 1,
          timezone: "Asia/Tokyo",
          default_start_time: null,
          default_end_time: null,
          locale: "ja",
          created_at: "2026-01-01",
          updated_at: "2026-01-01",
        },
      });

    const consoleErrorSpy = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});
    const consoleLogSpy = jest
      .spyOn(console, "log")
      .mockImplementation(() => {});

    await handleReady(client);

    // エラーサーバーのエラーがログに記録されること
    expect(consoleErrorSpy).toHaveBeenCalledWith(
      expect.stringContaining("キャッシュ復元エラー"),
      expect.any(Error)
    );

    // 正常サーバーはキャッシュに登録されること
    expect(mockSetGroup).toHaveBeenCalledWith("guild-ok", {
      groupId: 30,
      shareToken: "token-ok",
    });
  });

  it("Bot のステータスを設定すること", async () => {
    const client = createMockClient([]);

    const consoleSpy = jest
      .spyOn(console, "log")
      .mockImplementation(() => {});

    await handleReady(client);

    expect(client.user.setActivity).toHaveBeenCalledWith(
      "/schedule でスケジュール管理",
      { type: ActivityType.Playing }
    );
  });

  it("サーバーが0個でも正常に完了すること", async () => {
    const client = createMockClient([]);

    const consoleSpy = jest
      .spyOn(console, "log")
      .mockImplementation(() => {});

    await expect(handleReady(client)).resolves.toBeUndefined();

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining("初期化完了")
    );
  });
});
