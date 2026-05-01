import axios, { AxiosInstance, AxiosError } from "axios";
import type {
  CreateGroupParams,
  CreateGroupResponse,
  SyncMemberEntry,
  SyncMembersResponse,
  WeeklyStatusResponse,
  ApiErrorResponse,
} from "../types.js";

// Rails 内部 API クライアント
// Discord Bot から Rails API への通信を担当する
// Bot トークン認証（Bearer）を使用する

// 環境変数から設定を取得
const API_BASE_URL = process.env.API_BASE_URL || "http://api:3000";
const INTERNAL_API_TOKEN = process.env.INTERNAL_API_TOKEN || "";

// axios インスタンスの作成
const client: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000, // 10秒タイムアウト
  headers: {
    "Content-Type": "application/json",
    Authorization: `Bearer ${INTERNAL_API_TOKEN}`,
  },
});

// レスポンスインターセプター: API エラーをログ出力
client.interceptors.response.use(
  (response) => response,
  (error: AxiosError<ApiErrorResponse>) => {
    if (error.response) {
      const { status, data } = error.response;
      console.error(
        `[API エラー] ステータス: ${status}, コード: ${data?.error?.code || "UNKNOWN"}, メッセージ: ${data?.error?.message || error.message}`
      );
      if (data?.error?.details) {
        console.error(
          `[API エラー詳細]`,
          JSON.stringify(data.error.details, null, 2)
        );
      }
    } else if (error.request) {
      console.error(
        `[API エラー] リクエスト送信失敗: ${error.message}`
      );
    } else {
      console.error(`[API エラー] ${error.message}`);
    }
    return Promise.reject(error);
  }
);

// グループを作成する
// POST /api/internal/groups
export async function createGroup(
  params: CreateGroupParams
): Promise<CreateGroupResponse> {
  const response = await client.post<CreateGroupResponse>(
    "/api/internal/groups",
    params
  );
  return response.data;
}

// メンバーを同期する
// POST /api/internal/groups/:id/sync_members
export async function syncMembers(
  groupId: number,
  members: SyncMemberEntry[]
): Promise<SyncMembersResponse> {
  const response = await client.post<SyncMembersResponse>(
    `/api/internal/groups/${groupId}/sync_members`,
    { members }
  );
  return response.data;
}

// 週次入力状況を取得する
// GET /api/internal/groups/:id/weekly_status
export async function getWeeklyStatus(
  groupId: number
): Promise<WeeklyStatusResponse> {
  const response = await client.get<WeeklyStatusResponse>(
    `/api/internal/groups/${groupId}/weekly_status`
  );
  return response.data;
}

// guild_id からグループを検索する
// POST /api/internal/groups に guild_id を送信し、既存グループがあればそれを返す
// （createGroup API は既存グループがあればそれを返す仕様）
export async function findGroupByGuildId(
  guildId: string
): Promise<CreateGroupResponse | null> {
  try {
    const response = await client.post<CreateGroupResponse>(
      "/api/internal/groups",
      { guild_id: guildId }
    );
    return response.data;
  } catch (error) {
    if (axios.isAxiosError(error) && error.response?.status === 400) {
      // guild_id のみでは owner 情報が不足するため 400 が返る場合がある
      return null;
    }
    throw error;
  }
}

export default client;
