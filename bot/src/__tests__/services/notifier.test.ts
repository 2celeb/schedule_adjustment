/**
 * notifier サービスのユニットテスト
 * チャンネル投稿、DM 送信、メンション生成のロジックを検証する
 * 要件: 6.2, 6.3, 6.5
 */

import {
  sendChannelMessage,
  sendDm,
  sendBulkDm,
  buildMentions,
  sendWithFallback,
} from "../../services/notifier";
import { ChannelType, DiscordAPIError } from "discord.js";
import type { Client, TextChannel, DMChannel, User } from "discord.js";

// Discord クライアントのモック
function createMockClient(overrides: Partial<{
  channelFetch: jest.Mock;
  userFetch: jest.Mock;
}> = {}): Client {
  return {
    channels: {
      fetch: overrides.channelFetch || jest.fn(),
    },
    users: {
      fetch: overrides.userFetch || jest.fn(),
    },
  } as unknown as Client;
}

describe("notifier", () => {
  describe("sendChannelMessage", () => {
    it("テキストチャンネルにメッセージを送信できること", async () => {
      const mockSend = jest.fn().mockResolvedValue(undefined);
      const mockChannel = {
        type: ChannelType.GuildText,
        send: mockSend,
      } as unknown as TextChannel;

      const client = createMockClient({
        channelFetch: jest.fn().mockResolvedValue(mockChannel),
      });

      const result = await sendChannelMessage(client, "channel-123", "テストメッセージ");

      expect(result).toBe(true);
      expect(mockSend).toHaveBeenCalledWith("テストメッセージ");
    });

    it("チャンネルが見つからない場合は false を返すこと", async () => {
      const client = createMockClient({
        channelFetch: jest.fn().mockResolvedValue(null),
      });

      const result = await sendChannelMessage(client, "invalid-channel", "テスト");

      expect(result).toBe(false);
    });

    it("テキストチャンネルでない場合は false を返すこと", async () => {
      const mockChannel = {
        type: ChannelType.GuildVoice,
      };

      const client = createMockClient({
        channelFetch: jest.fn().mockResolvedValue(mockChannel),
      });

      const result = await sendChannelMessage(client, "voice-channel", "テスト");

      expect(result).toBe(false);
    });

    it("Discord API エラー時は false を返すこと", async () => {
      const client = createMockClient({
        channelFetch: jest.fn().mockRejectedValue(new Error("API Error")),
      });

      const result = await sendChannelMessage(client, "channel-123", "テスト");

      expect(result).toBe(false);
    });
  });

  describe("sendDm", () => {
    it("ユーザーに DM を送信できること", async () => {
      const mockDmSend = jest.fn().mockResolvedValue(undefined);
      const mockDmChannel = { send: mockDmSend } as unknown as DMChannel;
      const mockUser = {
        createDM: jest.fn().mockResolvedValue(mockDmChannel),
      } as unknown as User;

      const client = createMockClient({
        userFetch: jest.fn().mockResolvedValue(mockUser),
      });

      const result = await sendDm(client, "user-123", "DM テスト");

      expect(result.success).toBe(true);
      expect(result.discordUserId).toBe("user-123");
      expect(mockDmSend).toHaveBeenCalledWith("DM テスト");
    });

    it("DM 無効ユーザーの場合は失敗結果を返すこと", async () => {
      const apiError = new DiscordAPIError(
        { code: 50007, message: "Cannot send messages to this user" } as any,
        50007,
        403,
        "POST",
        "/channels/123/messages",
        {} as any,
      );

      const mockUser = {
        createDM: jest.fn().mockRejectedValue(apiError),
      } as unknown as User;

      const client = createMockClient({
        userFetch: jest.fn().mockResolvedValue(mockUser),
      });

      const result = await sendDm(client, "user-dm-disabled", "テスト");

      expect(result.success).toBe(false);
      expect(result.discordUserId).toBe("user-dm-disabled");
      expect(result.error).toContain("DM が無効");
    });

    it("ユーザーが見つからない場合は失敗結果を返すこと", async () => {
      const client = createMockClient({
        userFetch: jest.fn().mockRejectedValue(new Error("Unknown User")),
      });

      const result = await sendDm(client, "unknown-user", "テスト");

      expect(result.success).toBe(false);
      expect(result.error).toBeDefined();
    });
  });

  describe("sendBulkDm", () => {
    it("複数ユーザーに DM を送信できること", async () => {
      const mockDmSend = jest.fn().mockResolvedValue(undefined);
      const mockDmChannel = { send: mockDmSend } as unknown as DMChannel;
      const mockUser = {
        createDM: jest.fn().mockResolvedValue(mockDmChannel),
      } as unknown as User;

      const client = createMockClient({
        userFetch: jest.fn().mockResolvedValue(mockUser),
      });

      const targets = [
        { discordUserId: "user-1", content: "メッセージ1" },
        { discordUserId: "user-2", content: "メッセージ2" },
      ];

      const results = await sendBulkDm(client, targets);

      expect(results).toHaveLength(2);
      expect(results[0].success).toBe(true);
      expect(results[1].success).toBe(true);
    });

    it("1件の失敗が他に影響しないこと", async () => {
      const mockDmSend = jest.fn().mockResolvedValue(undefined);
      const mockDmChannel = { send: mockDmSend } as unknown as DMChannel;

      let callCount = 0;
      const client = createMockClient({
        userFetch: jest.fn().mockImplementation(() => {
          callCount++;
          if (callCount === 1) {
            return Promise.reject(new Error("User not found"));
          }
          return Promise.resolve({
            createDM: jest.fn().mockResolvedValue(mockDmChannel),
          });
        }),
      });

      const targets = [
        { discordUserId: "user-fail", content: "失敗" },
        { discordUserId: "user-success", content: "成功" },
      ];

      const results = await sendBulkDm(client, targets);

      expect(results).toHaveLength(2);
      expect(results[0].success).toBe(false);
      expect(results[1].success).toBe(true);
    });
  });

  describe("buildMentions", () => {
    it("メンション文字列を正しく生成すること", () => {
      const result = buildMentions(["123", "456", "789"]);
      expect(result).toBe("<@123> <@456> <@789>");
    });

    it("空配列の場合は空文字列を返すこと", () => {
      const result = buildMentions([]);
      expect(result).toBe("");
    });

    it("1件の場合はスペースなしで返すこと", () => {
      const result = buildMentions(["123"]);
      expect(result).toBe("<@123>");
    });
  });

  describe("sendWithFallback", () => {
    it("優先チャンネルに送信成功した場合はフォールバックしないこと", async () => {
      const mockSend = jest.fn().mockResolvedValue(undefined);
      const mockChannel = {
        type: ChannelType.GuildText,
        send: mockSend,
      } as unknown as TextChannel;

      const channelFetch = jest.fn().mockResolvedValue(mockChannel);
      const client = createMockClient({ channelFetch });

      const result = await sendWithFallback(
        client,
        "primary-channel",
        "fallback-channel",
        "テスト",
      );

      expect(result).toBe(true);
      expect(channelFetch).toHaveBeenCalledTimes(1);
    });

    it("優先チャンネル失敗時にフォールバックチャンネルに送信すること", async () => {
      let callCount = 0;
      const mockSend = jest.fn().mockResolvedValue(undefined);

      const channelFetch = jest.fn().mockImplementation((id: string) => {
        callCount++;
        if (callCount === 1) {
          return Promise.resolve(null); // 優先チャンネルが見つからない
        }
        return Promise.resolve({
          type: ChannelType.GuildText,
          send: mockSend,
        });
      });

      const client = createMockClient({ channelFetch });

      const result = await sendWithFallback(
        client,
        "invalid-channel",
        "fallback-channel",
        "テスト",
      );

      expect(result).toBe(true);
      expect(channelFetch).toHaveBeenCalledTimes(2);
    });

    it("フォールバックチャンネルがない場合は false を返すこと", async () => {
      const client = createMockClient({
        channelFetch: jest.fn().mockResolvedValue(null),
      });

      const result = await sendWithFallback(
        client,
        "invalid-channel",
        undefined,
        "テスト",
      );

      expect(result).toBe(false);
    });
  });
});
