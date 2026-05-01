/**
 * initialSetup（初回設定フロー）のユニットテスト
 * /schedule コマンド初回実行時のグループ作成・メンバー同期を検証する
 * 要件: 2.1, 2.2, 8.1, 8.5
 */

import { createMockInteraction, createMockGuildMember } from "../helpers/discordMocks";
import type { GuildMember } from "discord.js";

// apiClient をモック化
jest.mock("../../services/apiClient", () => ({
  createGroup: jest.fn(),
  syncMembers: jest.fn(),
}));

// guildGroupMap をモック化
jest.mock("../../services/guildGroupMap", () => ({
  setGroup: jest.fn(),
  getGroup: jest.fn(),
  removeGroup: jest.fn(),
}));

import { runInitialSetup } from "../../setup/initialSetup";
import * as apiClient from "../../services/apiClient";
import { setGroup } from "../../services/guildGroupMap";

describe("initialSetup", () => {
  const mockCreateGroup = apiClient.createGroup as jest.MockedFunction<
    typeof apiClient.createGroup
  >;
  const mockSyncMembers = apiClient.syncMembers as jest.MockedFunction<
    typeof apiClient.syncMembers
  >;
  const mockSetGroup = setGroup as jest.MockedFunction<typeof setGroup>;

  beforeEach(() => {
    process.env.FRONTEND_URL = "http://localhost";
  });

  function setupMockGuildMembers(
    interaction: any,
    members: GuildMember[]
  ): void {
    const memberMap = new Map(members.map((m) => [m.user.id, m]));
    interaction.guild.members.fetch = jest.fn().mockResolvedValue(memberMap);
  }

  it("guild がない場合にエラーを返すこと", async () => {
    const interaction = createMockInteraction();
    (interaction as any).guild = null;

    const result = await runInitialSetup(interaction);

    expect(result.success).toBe(false);
    expect(result.error).toContain("サーバー情報");
  });

  it("正常にグループ作成・メンバー同期・キャッシュ登録を行うこと", async () => {
    const interaction = createMockInteraction({
      guildId: "guild-100",
      guildName: "テストサーバー",
      userId: "owner-1",
      displayName: "オーナー",
      channelId: "ch-1",
    });

    // メンバーリスト（Owner + 2名の一般メンバー）
    const ownerMember = createMockGuildMember({
      userId: "owner-1",
      displayName: "オーナー",
      guildId: "guild-100",
    });
    const member1 = createMockGuildMember({
      userId: "user-2",
      displayName: "メンバー2",
      guildId: "guild-100",
    });
    const member2 = createMockGuildMember({
      userId: "user-3",
      displayName: "メンバー3",
      guildId: "guild-100",
    });

    setupMockGuildMembers(interaction, [ownerMember, member1, member2]);

    mockCreateGroup.mockResolvedValue({
      group: {
        id: 1,
        name: "テストサーバー",
        event_name: "テストサーバーの活動",
        owner_id: 42,
        share_token: "new-token",
        timezone: "Asia/Tokyo",
        default_start_time: null,
        default_end_time: null,
        locale: "ja",
        created_at: "2026-01-01",
        updated_at: "2026-01-01",
      },
    });

    mockSyncMembers.mockResolvedValue({
      group_id: 1,
      results: {
        added: [
          { discord_user_id: "user-2", user_id: 2 },
          { discord_user_id: "user-3", user_id: 3 },
        ],
        updated: [],
        skipped: [],
        errors: [],
      },
    });

    const result = await runInitialSetup(interaction);

    // グループ作成 API が正しいパラメータで呼ばれること
    expect(mockCreateGroup).toHaveBeenCalledWith({
      guild_id: "guild-100",
      name: "テストサーバー",
      owner_discord_user_id: "owner-1",
      owner_discord_screen_name: "オーナー",
      default_channel_id: "ch-1",
    });

    // メンバー同期で Owner が除外されていること
    expect(mockSyncMembers).toHaveBeenCalledWith(1, [
      { discord_user_id: "user-2", discord_screen_name: "メンバー2" },
      { discord_user_id: "user-3", discord_screen_name: "メンバー3" },
    ]);

    // キャッシュに登録されること
    expect(mockSetGroup).toHaveBeenCalledWith("guild-100", {
      groupId: 1,
      shareToken: "new-token",
    });

    // 成功結果
    expect(result.success).toBe(true);
    expect(result.groupId).toBe(1);
    expect(result.shareToken).toBe("new-token");

    // 完了メッセージにスケジュール URL が含まれること
    const editReplyCall = (interaction.editReply as jest.Mock).mock.calls;
    const lastCall = editReplyCall[editReplyCall.length - 1][0];
    expect(lastCall.content).toContain("/groups/new-token");
    expect(lastCall.content).toContain("3名を登録しました");
  });

  it("Bot ユーザーがメンバー同期から除外されること", async () => {
    const interaction = createMockInteraction({
      guildId: "guild-100",
      userId: "owner-1",
    });

    // Bot メンバーを含むリスト
    const botMember = createMockGuildMember({
      userId: "bot-user-id",
      displayName: "TestBot",
      isBot: true,
      guildId: "guild-100",
    });
    const humanMember = createMockGuildMember({
      userId: "user-2",
      displayName: "人間メンバー",
      guildId: "guild-100",
    });

    setupMockGuildMembers(interaction, [botMember, humanMember]);

    mockCreateGroup.mockResolvedValue({
      group: {
        id: 1,
        name: "テスト",
        event_name: "テスト",
        owner_id: 1,
        share_token: "token",
        timezone: "Asia/Tokyo",
        default_start_time: null,
        default_end_time: null,
        locale: "ja",
        created_at: "2026-01-01",
        updated_at: "2026-01-01",
      },
    });

    mockSyncMembers.mockResolvedValue({
      group_id: 1,
      results: { added: [], updated: [], skipped: [], errors: [] },
    });

    await runInitialSetup(interaction);

    // Bot ユーザーが同期リストに含まれないこと
    const syncCall = mockSyncMembers.mock.calls[0];
    const syncedMembers = syncCall[1];
    const botInList = syncedMembers.some(
      (m) => m.discord_user_id === "bot-user-id"
    );
    expect(botInList).toBe(false);
  });

  it("メンバー数が上限（20名）を超える場合に最初の19名のみ同期すること", async () => {
    const interaction = createMockInteraction({
      guildId: "guild-100",
      userId: "owner-1",
    });

    // Owner + 25名の一般メンバー（合計26名、上限20名を超過）
    const members: GuildMember[] = [];
    for (let i = 0; i < 25; i++) {
      members.push(
        createMockGuildMember({
          userId: `user-${i}`,
          displayName: `メンバー${i}`,
          guildId: "guild-100",
        })
      );
    }

    setupMockGuildMembers(interaction, members);

    mockCreateGroup.mockResolvedValue({
      group: {
        id: 1,
        name: "テスト",
        event_name: "テスト",
        owner_id: 1,
        share_token: "token",
        timezone: "Asia/Tokyo",
        default_start_time: null,
        default_end_time: null,
        locale: "ja",
        created_at: "2026-01-01",
        updated_at: "2026-01-01",
      },
    });

    mockSyncMembers.mockResolvedValue({
      group_id: 1,
      results: { added: [], updated: [], skipped: [], errors: [] },
    });

    const result = await runInitialSetup(interaction);

    // 同期されるメンバー数が 19 以下であること（Owner 分の 1 を引いた上限）
    const syncCall = mockSyncMembers.mock.calls[0];
    expect(syncCall[1].length).toBeLessThanOrEqual(19);

    // 上限超過メッセージが含まれること
    const editReplyCalls = (interaction.editReply as jest.Mock).mock.calls;
    const lastCall = editReplyCalls[editReplyCalls.length - 1][0];
    expect(lastCall.content).toContain("上限");
  });

  it("グループ作成 API エラー時にエラーメッセージを返すこと", async () => {
    const interaction = createMockInteraction({ guildId: "guild-100" });
    setupMockGuildMembers(interaction, []);

    mockCreateGroup.mockRejectedValue(new Error("API エラー"));

    const consoleSpy = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});

    const result = await runInitialSetup(interaction);

    expect(result.success).toBe(false);
    expect(interaction.editReply).toHaveBeenCalledWith({
      content: expect.stringContaining("失敗しました"),
    });
  });

  it("メンバー取得失敗時でもグループ作成は成功すること", async () => {
    const interaction = createMockInteraction({
      guildId: "guild-100",
      userId: "owner-1",
    });

    // メンバー取得を失敗させる
    interaction.guild!.members.fetch = jest
      .fn()
      .mockRejectedValue(new Error("Members Intent エラー"));

    mockCreateGroup.mockResolvedValue({
      group: {
        id: 1,
        name: "テスト",
        event_name: "テスト",
        owner_id: 1,
        share_token: "token-ok",
        timezone: "Asia/Tokyo",
        default_start_time: null,
        default_end_time: null,
        locale: "ja",
        created_at: "2026-01-01",
        updated_at: "2026-01-01",
      },
    });

    const consoleSpy = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});

    const result = await runInitialSetup(interaction);

    // グループ作成は成功
    expect(result.success).toBe(true);

    // メンバー同期は呼ばれない（メンバー取得失敗のため）
    expect(mockSyncMembers).not.toHaveBeenCalled();

    // 警告メッセージが含まれること
    const editReplyCalls = (interaction.editReply as jest.Mock).mock.calls;
    const lastCall = editReplyCalls[editReplyCalls.length - 1][0];
    expect(lastCall.content).toContain("自動取得に失敗");
  });

  it("メンバー同期失敗時でもグループ作成は成功すること", async () => {
    const interaction = createMockInteraction({
      guildId: "guild-100",
      userId: "owner-1",
    });

    const member = createMockGuildMember({
      userId: "user-2",
      displayName: "メンバー",
      guildId: "guild-100",
    });
    setupMockGuildMembers(interaction, [member]);

    mockCreateGroup.mockResolvedValue({
      group: {
        id: 1,
        name: "テスト",
        event_name: "テスト",
        owner_id: 1,
        share_token: "token-ok",
        timezone: "Asia/Tokyo",
        default_start_time: null,
        default_end_time: null,
        locale: "ja",
        created_at: "2026-01-01",
        updated_at: "2026-01-01",
      },
    });

    mockSyncMembers.mockRejectedValue(new Error("同期エラー"));

    const consoleSpy = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});

    const result = await runInitialSetup(interaction);

    // グループ作成は成功
    expect(result.success).toBe(true);
    expect(mockSetGroup).toHaveBeenCalled();
  });

  it("完了メッセージにグループ名・メンバー数・URL・設定案内が含まれること", async () => {
    const interaction = createMockInteraction({
      guildId: "guild-100",
      guildName: "フォーマットテスト",
      userId: "owner-1",
      channelId: "ch-1",
    });

    const member1 = createMockGuildMember({
      userId: "user-2",
      displayName: "メンバーA",
      guildId: "guild-100",
    });
    setupMockGuildMembers(interaction, [member1]);

    mockCreateGroup.mockResolvedValue({
      group: {
        id: 1,
        name: "フォーマットテスト",
        event_name: "テスト",
        owner_id: 1,
        share_token: "fmt-token",
        timezone: "Asia/Tokyo",
        default_start_time: null,
        default_end_time: null,
        locale: "ja",
        created_at: "2026-01-01",
        updated_at: "2026-01-01",
      },
    });

    mockSyncMembers.mockResolvedValue({
      group_id: 1,
      results: {
        added: [{ discord_user_id: "user-2", user_id: 2 }],
        updated: [],
        skipped: [],
        errors: [],
      },
    });

    await runInitialSetup(interaction);

    const editReplyCalls = (interaction.editReply as jest.Mock).mock.calls;
    const lastCall = editReplyCalls[editReplyCalls.length - 1][0];
    const content = lastCall.content as string;

    // ✅ 完了アイコン
    expect(content).toContain("✅");
    // グループ名
    expect(content).toContain("フォーマットテスト");
    // メンバー数（Owner 1 + 同期 1 = 2名）
    expect(content).toContain("2名を登録しました");
    // スケジュール URL
    expect(content).toContain("/groups/fmt-token");
    // 設定案内
    expect(content).toContain("/settings");
  });
});
