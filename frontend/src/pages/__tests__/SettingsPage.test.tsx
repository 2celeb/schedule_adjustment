/**
 * SettingsPage コンポーネントのユニットテスト
 *
 * 要件: 6.8
 */
import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import SettingsPage from "@/pages/SettingsPage";

/** react-i18next をモック */
vi.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const translations: Record<string, string> = {
        "group.settings": "グループ設定",
        "autoSchedule.title": "自動確定ルール",
        "notification.title": "通知設定",
        "common.loading": "読み込み中...",
        "schedule.noGroup": "グループが見つかりません",
      };
      return translations[key] ?? key;
    },
  }),
}));

/** API クライアントをモック */
vi.mock("@/api/client", () => ({
  default: {
    get: vi.fn().mockResolvedValue({
      data: {
        group: {
          id: 1,
          name: "テストグループ",
          event_name: "テスト活動",
          owner_id: 1,
          share_token: "abc123",
          timezone: "Asia/Tokyo",
          default_start_time: "19:00",
          default_end_time: "22:00",
          threshold_n: 3,
          threshold_target: "core",
          ad_enabled: true,
          locale: "ja",
        },
      },
    }),
    put: vi.fn().mockResolvedValue({ data: {} }),
  },
}));

function renderWithProviders(shareToken: string = "abc123") {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[`/groups/${shareToken}/settings`]}>
        <Routes>
          <Route
            path="/groups/:share_token/settings"
            element={<SettingsPage />}
          />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("SettingsPage", () => {
  it("ローディング中は読み込み表示がされる", () => {
    renderWithProviders();

    expect(screen.getByText("読み込み中...")).toBeInTheDocument();
  });

  it("グループ設定タイトルが表示される", async () => {
    renderWithProviders();

    const title = await screen.findByText("グループ設定");
    expect(title).toBeInTheDocument();
  });

  it("タブが表示される", async () => {
    renderWithProviders();

    const autoScheduleTab = await screen.findByText("自動確定ルール");
    expect(autoScheduleTab).toBeInTheDocument();

    const notificationTab = screen.getByText("通知設定");
    expect(notificationTab).toBeInTheDocument();
  });

  it("グループ名が表示される", async () => {
    renderWithProviders();

    const groupName = await screen.findByText("テストグループ");
    expect(groupName).toBeInTheDocument();
  });
});
