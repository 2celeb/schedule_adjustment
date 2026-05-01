/**
 * reminderFormatter サービスのユニットテスト
 * リマインドメッセージ、予定一覧メッセージ、当日通知メッセージの整形を検証する
 * 要件: 6.2, 6.3, 6.5
 */

import {
  formatChannelRemind,
  formatDmRemind,
  formatScheduleConfirmed,
  formatDailyNotify,
} from "../../services/reminderFormatter";

describe("reminderFormatter", () => {
  describe("formatChannelRemind", () => {
    it("メンション付きリマインドメッセージを生成すること", () => {
      const result = formatChannelRemind(
        "テストグループ",
        "abc123",
        "2026-05-04",
        "2026-05-10",
        ["user-1", "user-2"],
        ["ユーザー1", "ユーザー2"],
      );

      expect(result).toContain("テストグループ");
      expect(result).toContain("スケジュール入力リマインド");
      expect(result).toContain("2026-05-04");
      expect(result).toContain("2026-05-10");
      expect(result).toContain("<@user-1>");
      expect(result).toContain("<@user-2>");
      expect(result).toContain("abc123");
    });

    it("Discord ユーザー ID がない場合は名前のみ表示すること", () => {
      const result = formatChannelRemind(
        "テストグループ",
        "abc123",
        "2026-05-04",
        "2026-05-10",
        [],
        ["ユーザー1", "ユーザー2"],
      );

      expect(result).not.toContain("<@");
      expect(result).toContain("ユーザー1");
      expect(result).toContain("ユーザー2");
    });
  });

  describe("formatDmRemind", () => {
    it("個別 DM メッセージを生成すること", () => {
      const result = formatDmRemind(
        "テストユーザー",
        "テストグループ",
        "abc123",
        "2026-05-04",
        "2026-05-10",
      );

      expect(result).toContain("テストユーザー");
      expect(result).toContain("テストグループ");
      expect(result).toContain("2026-05-04");
      expect(result).toContain("2026-05-10");
      expect(result).toContain("abc123");
      expect(result).toContain("自動送信");
    });
  });

  describe("formatScheduleConfirmed", () => {
    it("活動日確定メッセージを生成すること", () => {
      const result = formatScheduleConfirmed(
        "テストグループ",
        "テスト活動",
        [
          { date: "2026-05-06", start_time: "19:00", end_time: "22:00" },
          { date: "2026-05-08", start_time: "19:00", end_time: "22:00" },
        ],
      );

      expect(result).toContain("テストグループ");
      expect(result).toContain("確定");
      expect(result).toContain("2026-05-06");
      expect(result).toContain("2026-05-08");
      expect(result).toContain("19:00〜22:00");
    });

    it("活動日がない場合は「活動日なし」メッセージを表示すること", () => {
      const result = formatScheduleConfirmed(
        "テストグループ",
        "テスト活動",
        [],
      );

      expect(result).toContain("活動日はありません");
    });

    it("時間が未設定の場合は時間を表示しないこと", () => {
      const result = formatScheduleConfirmed(
        "テストグループ",
        "テスト活動",
        [{ date: "2026-05-06" }],
      );

      expect(result).toContain("2026-05-06");
      expect(result).not.toContain("〜");
    });
  });

  describe("formatDailyNotify", () => {
    const members = [
      { display_name: "ユーザーA", discord_user_id: "user-a", role: "core", status: 1 },
      { display_name: "ユーザーB", discord_user_id: "user-b", role: "core", status: 0 },
      { display_name: "ユーザーC", discord_user_id: "user-c", role: "sub", status: -1 },
      { display_name: "ユーザーD", discord_user_id: "user-d", role: "sub", status: null },
    ];

    it("当日通知メッセージを生成すること", () => {
      const result = formatDailyNotify(
        "テストグループ",
        "テスト活動",
        "2026-05-06",
        "19:00",
        "22:00",
        members,
        null,
        "abc123",
      );

      expect(result).toContain("本日は テスト活動 の活動日です");
      expect(result).toContain("19:00 〜 22:00");
      expect(result).toContain("参加 (1)");
      expect(result).toContain("ユーザーA");
      expect(result).toContain("未定 (1)");
      expect(result).toContain("ユーザーB");
      expect(result).toContain("不参加 (1)");
      expect(result).toContain("ユーザーC");
      expect(result).toContain("未入力 (1)");
      expect(result).toContain("ユーザーD");
      expect(result).toContain("abc123");
    });

    it("カスタムメッセージが設定されている場合はそれを使用すること", () => {
      const result = formatDailyNotify(
        "テストグループ",
        "テスト活動",
        "2026-05-06",
        "19:00",
        "22:00",
        members,
        "今日はサッカーの日です！",
        "abc123",
      );

      expect(result).toContain("今日はサッカーの日です！");
      expect(result).not.toContain("本日は テスト活動 の活動日です");
    });

    it("メンションが含まれないこと", () => {
      const result = formatDailyNotify(
        "テストグループ",
        "テスト活動",
        "2026-05-06",
        "19:00",
        "22:00",
        members,
      );

      expect(result).not.toContain("<@");
    });

    it("時間が未設定の場合は時間を表示しないこと", () => {
      const result = formatDailyNotify(
        "テストグループ",
        "テスト活動",
        "2026-05-06",
        null,
        null,
        members,
      );

      expect(result).not.toContain("⏰");
    });

    it("shareToken がない場合はリンクを表示しないこと", () => {
      const result = formatDailyNotify(
        "テストグループ",
        "テスト活動",
        "2026-05-06",
        "19:00",
        "22:00",
        members,
      );

      expect(result).not.toContain("🔗");
    });
  });
});
