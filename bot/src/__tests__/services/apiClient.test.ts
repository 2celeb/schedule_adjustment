/**
 * apiClient サービスのユニットテスト
 * Rails 内部 API クライアントの動作を検証する
 * 要件: 8.1
 */

// axios のモックインスタンスを先に定義
const mockPost = jest.fn();
const mockGet = jest.fn();

jest.mock("axios", () => {
  return {
    __esModule: true,
    default: {
      create: jest.fn(() => ({
        post: mockPost,
        get: mockGet,
        interceptors: {
          response: { use: jest.fn() },
          request: { use: jest.fn() },
        },
      })),
      isAxiosError: jest.fn(),
    },
    isAxiosError: jest.fn(),
  };
});

import axios from "axios";
import {
  createGroup,
  syncMembers,
  getWeeklyStatus,
  findGroupByGuildId,
} from "../../services/apiClient";

describe("apiClient", () => {
  beforeEach(() => {
    mockPost.mockReset();
    mockGet.mockReset();
  });

  describe("createGroup", () => {
    it("グループ作成 API を正しく呼び出すこと", async () => {
      const mockResponse = {
        data: {
          group: {
            id: 1,
            name: "テストサーバー",
            share_token: "abc123",
            owner_id: 42,
          },
        },
      };
      mockPost.mockResolvedValue(mockResponse);

      const result = await createGroup({
        guild_id: "guild-123",
        name: "テストサーバー",
        owner_discord_user_id: "user-1",
        owner_discord_screen_name: "テストオーナー",
      });

      expect(mockPost).toHaveBeenCalledWith("/api/internal/groups", {
        guild_id: "guild-123",
        name: "テストサーバー",
        owner_discord_user_id: "user-1",
        owner_discord_screen_name: "テストオーナー",
      });
      expect(result.group.id).toBe(1);
      expect(result.group.name).toBe("テストサーバー");
    });

    it("API エラー時に例外をスローすること", async () => {
      mockPost.mockRejectedValue(new Error("API エラー"));

      await expect(
        createGroup({
          guild_id: "guild-123",
          name: "テスト",
          owner_discord_user_id: "user-1",
          owner_discord_screen_name: "テスト",
        })
      ).rejects.toThrow("API エラー");
    });
  });

  describe("syncMembers", () => {
    it("メンバー同期 API を正しく呼び出すこと", async () => {
      const mockResponse = {
        data: {
          group_id: 1,
          results: {
            added: [{ discord_user_id: "user-2", user_id: 2 }],
            updated: [],
            skipped: [],
            errors: [],
          },
        },
      };
      mockPost.mockResolvedValue(mockResponse);

      const members = [
        {
          discord_user_id: "user-2",
          discord_screen_name: "メンバー2",
        },
      ];

      const result = await syncMembers(1, members);

      expect(mockPost).toHaveBeenCalledWith(
        "/api/internal/groups/1/sync_members",
        { members }
      );
      expect(result.results.added).toHaveLength(1);
      expect(result.results.added[0].discord_user_id).toBe("user-2");
    });

    it("グループ ID がパスに正しく含まれること", async () => {
      mockPost.mockResolvedValue({
        data: {
          group_id: 99,
          results: { added: [], updated: [], skipped: [], errors: [] },
        },
      });

      await syncMembers(99, []);

      expect(mockPost).toHaveBeenCalledWith(
        "/api/internal/groups/99/sync_members",
        { members: [] }
      );
    });
  });

  describe("getWeeklyStatus", () => {
    it("週次入力状況 API を正しく呼び出すこと", async () => {
      const mockResponse = {
        data: {
          group: { id: 1, name: "テスト", share_token: "abc" },
          week_start: "2026-05-04",
          week_end: "2026-05-10",
          members: [
            {
              user_id: 1,
              display_name: "テストユーザー",
              discord_user_id: "user-1",
              role: "core",
              dates: [],
              filled_count: 5,
              total_days: 7,
            },
          ],
        },
      };
      mockGet.mockResolvedValue(mockResponse);

      const result = await getWeeklyStatus(1);

      expect(mockGet).toHaveBeenCalledWith(
        "/api/internal/groups/1/weekly_status"
      );
      expect(result.week_start).toBe("2026-05-04");
      expect(result.members).toHaveLength(1);
      expect(result.members[0].filled_count).toBe(5);
    });
  });

  describe("findGroupByGuildId", () => {
    it("既存グループが見つかった場合にレスポンスを返すこと", async () => {
      const mockResponse = {
        data: {
          group: {
            id: 1,
            name: "テストサーバー",
            share_token: "abc123",
          },
        },
      };
      mockPost.mockResolvedValue(mockResponse);

      const result = await findGroupByGuildId("guild-123");

      expect(mockPost).toHaveBeenCalledWith("/api/internal/groups", {
        guild_id: "guild-123",
      });
      expect(result).not.toBeNull();
      expect(result!.group.share_token).toBe("abc123");
    });

    it("400 エラー時に null を返すこと（owner 情報不足）", async () => {
      const error = { response: { status: 400 } };
      mockPost.mockRejectedValue(error);
      (axios.isAxiosError as unknown as jest.Mock).mockReturnValue(true);

      const result = await findGroupByGuildId("guild-123");

      expect(result).toBeNull();
    });

    it("400 以外のエラー時に例外をスローすること", async () => {
      const error = { response: { status: 500 } };
      mockPost.mockRejectedValue(error);
      (axios.isAxiosError as unknown as jest.Mock).mockReturnValue(true);

      await expect(findGroupByGuildId("guild-123")).rejects.toEqual(error);
    });

    it("ネットワークエラー時に例外をスローすること", async () => {
      const error = new Error("Network Error");
      mockPost.mockRejectedValue(error);
      (axios.isAxiosError as unknown as jest.Mock).mockReturnValue(false);

      await expect(findGroupByGuildId("guild-123")).rejects.toThrow(
        "Network Error"
      );
    });
  });
});
