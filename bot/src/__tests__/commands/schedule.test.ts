/**
 * /schedule コマンドのユニットテスト
 * スケジュールページ URL の表示と初回設定フローの起動を検証する
 * 要件: 8.2
 */

import { createMockInteraction } from "../helpers/discordMocks";

// apiClient をモック化
jest.mock("../../services/apiClient", () => ({
  findGroupByGuildId: jest.fn(),
  createGroup: jest.fn(),
  syncMembers: jest.fn(),
}));

// guildGroupMap をモック化
jest.mock("../../services/guildGroupMap", () => ({
  getGroup: jest.fn(),
  setGroup: jest.fn(),
  removeGroup: jest.fn(),
}));

// initialSetup をモック化
jest.mock("../../setup/initialSetup", () => ({
  runInitialSetup: jest.fn(),
}));

import schedule from "../../commands/schedule";
import * as apiClient from "../../services/apiClient";
import { getGroup, setGroup } from "../../services/guildGroupMap";
import { runInitialSetup } from "../../setup/initialSetup";

describe("/schedule コマンド", () => {
  const mockGetGroup = getGroup as jest.MockedFunction<typeof getGroup>;
  const mockSetGroup = setGroup as jest.MockedFunction<typeof setGroup>;
  const mockFindGroup = apiClient.findGroupByGuildId as jest.MockedFunction<
    typeof apiClient.findGroupByGuildId
  >;
  const mockRunInitialSetup = runInitialSetup as jest.MockedFunction<
    typeof runInitialSetup
  >;

  beforeEach(() => {
    // 環境変数を設定
    process.env.FRONTEND_URL = "http://localhost";
  });

  it("コマンド名が schedule であること", () => {
    expect(schedule.data.name).toBe("schedule");
  });

  it("DM で実行した場合にエラーメッセージを返すこと", async () => {
    const interaction = createMockInteraction();
    // guild を null にして DM を模擬
    (interaction as any).guild = null;

    await schedule.execute(interaction);

    expect(interaction.reply).toHaveBeenCalledWith({
      content: "このコマンドはサーバー内でのみ使用できます。",
      ephemeral: true,
    });
  });

  it("キャッシュにグループがある場合に URL を返信すること", async () => {
    const interaction = createMockInteraction({ guildId: "guild-100" });
    mockGetGroup.mockReturnValue({
      groupId: 1,
      shareToken: "cached-token",
    });

    await schedule.execute(interaction);

    expect(interaction.reply).toHaveBeenCalledWith({
      content: expect.stringContaining("/groups/cached-token"),
    });
    // deferReply は呼ばれない（キャッシュヒットのため即座に返信）
    expect(interaction.deferReply).not.toHaveBeenCalled();
  });

  it("キャッシュになく API でグループが見つかった場合に URL を返信しキャッシュに登録すること", async () => {
    const interaction = createMockInteraction({ guildId: "guild-200" });
    mockGetGroup.mockReturnValue(undefined);
    mockFindGroup.mockResolvedValue({
      group: {
        id: 5,
        name: "テストグループ",
        share_token: "api-token-xyz",
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

    await schedule.execute(interaction);

    expect(interaction.deferReply).toHaveBeenCalled();
    expect(mockSetGroup).toHaveBeenCalledWith("guild-200", {
      groupId: 5,
      shareToken: "api-token-xyz",
    });
    expect(interaction.editReply).toHaveBeenCalledWith({
      content: expect.stringContaining("/groups/api-token-xyz"),
    });
  });

  it("キャッシュになく API でもグループが見つからない場合に初回設定フローを開始すること", async () => {
    const interaction = createMockInteraction({ guildId: "guild-300" });
    mockGetGroup.mockReturnValue(undefined);
    mockFindGroup.mockResolvedValue(null);
    mockRunInitialSetup.mockResolvedValue({
      success: true,
      groupId: 1,
      shareToken: "new-token",
    });

    await schedule.execute(interaction);

    expect(interaction.deferReply).toHaveBeenCalled();
    expect(mockRunInitialSetup).toHaveBeenCalledWith(interaction);
  });

  it("API 検索でエラーが発生した場合に初回設定フローにフォールバックすること", async () => {
    const interaction = createMockInteraction({ guildId: "guild-400" });
    mockGetGroup.mockReturnValue(undefined);
    mockFindGroup.mockRejectedValue(new Error("API 接続エラー"));
    mockRunInitialSetup.mockResolvedValue({
      success: true,
      groupId: 1,
      shareToken: "token",
    });

    await schedule.execute(interaction);

    expect(mockRunInitialSetup).toHaveBeenCalledWith(interaction);
  });

  it("初回設定フローでエラーが発生した場合にエラーメッセージを返すこと", async () => {
    const interaction = createMockInteraction({ guildId: "guild-500" });
    mockGetGroup.mockReturnValue(undefined);
    mockFindGroup.mockResolvedValue(null);
    mockRunInitialSetup.mockRejectedValue(new Error("設定エラー"));

    await schedule.execute(interaction);

    expect(interaction.editReply).toHaveBeenCalledWith({
      content: expect.stringContaining("エラーが発生しました"),
    });
  });
});
