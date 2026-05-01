/**
 * Discord.js のモックヘルパー
 * テスト全体で再利用する Discord オブジェクトのモックファクトリ
 */

import type {
  ChatInputCommandInteraction,
  Guild,
  GuildMember,
  User,
  Client,
  Collection,
} from "discord.js";

// ChatInputCommandInteraction のモックを作成する
export function createMockInteraction(
  overrides: Partial<{
    guildId: string;
    guildName: string;
    userId: string;
    username: string;
    displayName: string;
    channelId: string;
    replied: boolean;
    deferred: boolean;
  }> = {}
): ChatInputCommandInteraction {
  const {
    guildId = "guild-123",
    guildName = "テストサーバー",
    userId = "user-owner-1",
    username = "test_owner",
    displayName = "テストオーナー",
    channelId = "channel-456",
    replied = false,
    deferred = false,
  } = overrides;

  const mockUser = {
    id: userId,
    username,
    displayName,
    bot: false,
    tag: `${username}#0001`,
  } as unknown as User;

  const mockGuild = {
    id: guildId,
    name: guildName,
    members: {
      fetch: jest.fn().mockResolvedValue(new Map()),
    },
  } as unknown as Guild;

  const mockMember = {
    displayName,
    user: mockUser,
  } as unknown as GuildMember;

  return {
    guild: mockGuild,
    user: mockUser,
    member: mockMember,
    channelId,
    replied,
    deferred,
    client: { user: { id: "bot-user-id" } } as unknown as Client,
    reply: jest.fn().mockResolvedValue(undefined),
    deferReply: jest.fn().mockResolvedValue(undefined),
    editReply: jest.fn().mockResolvedValue(undefined),
    followUp: jest.fn().mockResolvedValue(undefined),
    commandName: "schedule",
    isChatInputCommand: jest.fn().mockReturnValue(true),
  } as unknown as ChatInputCommandInteraction;
}

// GuildMember のモックを作成する
export function createMockGuildMember(
  overrides: Partial<{
    userId: string;
    username: string;
    displayName: string;
    guildId: string;
    guildName: string;
    isBot: boolean;
  }> = {}
): GuildMember {
  const {
    userId = "user-1",
    username = "test_user",
    displayName = "テストユーザー",
    guildId = "guild-123",
    guildName = "テストサーバー",
    isBot = false,
  } = overrides;

  return {
    user: {
      id: userId,
      username,
      displayName,
      bot: isBot,
      tag: `${username}#0001`,
    },
    displayName,
    guild: {
      id: guildId,
      name: guildName,
    },
  } as unknown as GuildMember;
}

// Discord Collection のモックを作成する
export function createMockCollection<K, V>(
  entries: [K, V][]
): Collection<K, V> {
  const map = new Map(entries);
  return {
    ...map,
    size: map.size,
    values: () => map.values(),
    entries: () => map.entries(),
    keys: () => map.keys(),
    forEach: (fn: (value: V, key: K) => void) => map.forEach(fn),
    get: (key: K) => map.get(key),
    has: (key: K) => map.has(key),
    [Symbol.iterator]: () => map[Symbol.iterator](),
  } as unknown as Collection<K, V>;
}
