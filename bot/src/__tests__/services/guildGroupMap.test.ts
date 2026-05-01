/**
 * guildGroupMap サービスのユニットテスト
 * guild_id → グループ情報のメモリキャッシュの動作を検証する
 */

import { setGroup, getGroup, removeGroup } from "../../services/guildGroupMap";

describe("guildGroupMap", () => {
  // 各テスト前にキャッシュをクリアする
  beforeEach(() => {
    // 既知のキーを削除してクリーンな状態にする
    removeGroup("guild-1");
    removeGroup("guild-2");
    removeGroup("guild-3");
  });

  describe("setGroup / getGroup", () => {
    it("グループ情報を登録し取得できること", () => {
      setGroup("guild-1", { groupId: 10, shareToken: "token-abc" });

      const result = getGroup("guild-1");
      expect(result).toEqual({ groupId: 10, shareToken: "token-abc" });
    });

    it("未登録の guild_id は undefined を返すこと", () => {
      const result = getGroup("unknown-guild");
      expect(result).toBeUndefined();
    });

    it("同じ guild_id で上書き登録できること", () => {
      setGroup("guild-1", { groupId: 10, shareToken: "token-old" });
      setGroup("guild-1", { groupId: 20, shareToken: "token-new" });

      const result = getGroup("guild-1");
      expect(result).toEqual({ groupId: 20, shareToken: "token-new" });
    });

    it("複数の guild_id を独立して管理できること", () => {
      setGroup("guild-1", { groupId: 10, shareToken: "token-1" });
      setGroup("guild-2", { groupId: 20, shareToken: "token-2" });

      expect(getGroup("guild-1")).toEqual({
        groupId: 10,
        shareToken: "token-1",
      });
      expect(getGroup("guild-2")).toEqual({
        groupId: 20,
        shareToken: "token-2",
      });
    });
  });

  describe("removeGroup", () => {
    it("登録済みのグループを削除できること", () => {
      setGroup("guild-1", { groupId: 10, shareToken: "token-abc" });

      const removed = removeGroup("guild-1");
      expect(removed).toBe(true);
      expect(getGroup("guild-1")).toBeUndefined();
    });

    it("未登録の guild_id の削除は false を返すこと", () => {
      const removed = removeGroup("unknown-guild");
      expect(removed).toBe(false);
    });

    it("削除後に他のグループに影響しないこと", () => {
      setGroup("guild-1", { groupId: 10, shareToken: "token-1" });
      setGroup("guild-2", { groupId: 20, shareToken: "token-2" });

      removeGroup("guild-1");

      expect(getGroup("guild-1")).toBeUndefined();
      expect(getGroup("guild-2")).toEqual({
        groupId: 20,
        shareToken: "token-2",
      });
    });
  });
});
