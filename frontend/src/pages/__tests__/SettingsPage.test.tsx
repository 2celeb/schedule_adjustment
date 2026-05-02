/**
 * SettingsPage コンポーネントのユニットテスト
 *
 * Owner のみアクセス可能な設定ページの統合テスト。
 * - 認証済み Owner はタブ形式で全設定コンポーネントにアクセスできる
 * - 未認証ユーザーや Owner 以外はアクセス拒否される
 *
 * 要件: 4.8, 5.2, 5.3, 5.4, 5.5, 6.8, 7.1
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import SettingsPage from "@/pages/SettingsPage";

/** react-i18next をモック */
vi.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string, fallback?: string) => {
      const translations: Record<string, string> = {
        "group.settings": "グループ設定",
        "groupSettings.title": "グループ基本設定",
        "threshold.title": "閾値設定",
        "autoSchedule.title": "自動確定ルール",
        "notification.title": "通知設定",
        "calendar.sync": "Google カレンダー同期",
        "common.loading": "読み込み中...",
        "schedule.noGroup": "グループが見つかりません",
        "settings.ownerOnly": "この設定ページは Owner のみアクセスできます。",
        "settings.loginRequired": "設定を変更するには Google 認証でログインしてください。",
        "settings.backToSchedule": "スケジュールページに戻る",
      };
      return translations[key] ?? fallback ?? key;
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
        owner: {
          id: 1,
          google_calendar_scope: null,
          google_account_id: null,
        },
      },
    }),
    put: vi.fn().mockResolvedValue({ data: {} }),
    patch: vi.fn().mockResolvedValue({ data: {} }),
  },
}));

/** useCurrentUser フックのモック（デフォルト: 認証済み Owner） */
const mockUseCurrentUser = vi.fn().mockReturnValue({
  selectedUserId: 1,
  isAuthenticated: true,
  isLoading: false,
  selectUser: vi.fn(),
});

vi.mock("@/hooks/useCurrentUser", () => ({
  useCurrentUser: () => mockUseCurrentUser(),
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
  beforeEach(() => {
    /* デフォルト: 認証済み Owner（owner_id=1） */
    mockUseCurrentUser.mockReturnValue({
      selectedUserId: 1,
      isAuthenticated: true,
      isLoading: false,
      selectUser: vi.fn(),
    });
  });

  it("ローディング中は読み込み表示がされる", () => {
    renderWithProviders();

    expect(screen.getByText("読み込み中...")).toBeInTheDocument();
  });

  it("グループ設定タイトルが表示される", async () => {
    renderWithProviders();

    const title = await screen.findByText("グループ設定");
    expect(title).toBeInTheDocument();
  });

  it("5つのタブが表示される", async () => {
    renderWithProviders();

    /* タブが表示されるまで待機（role ベースで一意に特定） */
    await screen.findByRole("tab", { name: "グループ基本設定" });

    expect(screen.getByRole("tab", { name: "グループ基本設定" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "閾値設定" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "自動確定ルール" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "通知設定" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "Google カレンダー同期" })).toBeInTheDocument();
  });

  it("グループ名が表示される", async () => {
    renderWithProviders();

    const groupName = await screen.findByText("テストグループ");
    expect(groupName).toBeInTheDocument();
  });

  it("デフォルトでグループ基本設定タブが表示される", async () => {
    renderWithProviders();

    await screen.findByRole("tab", { name: "グループ基本設定" });

    /* グループ基本設定タブとコンテンツ内の見出しの両方が表示されている */
    const elements = screen.getAllByText("グループ基本設定");
    expect(elements.length).toBeGreaterThanOrEqual(2);
  });

  it("閾値設定タブに切り替えできる", async () => {
    const user = userEvent.setup();
    renderWithProviders();

    await screen.findByRole("tab", { name: "グループ基本設定" });

    /* 閾値設定タブをクリック */
    const thresholdTab = screen.getByRole("tab", { name: "閾値設定" });
    await user.click(thresholdTab);

    /* 閾値設定のコンテンツが表示される */
    const thresholdTitles = screen.getAllByText("閾値設定");
    expect(thresholdTitles.length).toBeGreaterThanOrEqual(2);
  });

  it("自動確定ルールタブに切り替えできる", async () => {
    const user = userEvent.setup();
    renderWithProviders();

    await screen.findByRole("tab", { name: "グループ基本設定" });

    const autoScheduleTab = screen.getByRole("tab", { name: "自動確定ルール" });
    await user.click(autoScheduleTab);

    /* タブが選択状態になる */
    expect(autoScheduleTab).toHaveAttribute("aria-selected", "true");
  });

  it("通知設定タブに切り替えできる", async () => {
    const user = userEvent.setup();
    renderWithProviders();

    await screen.findByRole("tab", { name: "グループ基本設定" });

    const notificationTab = screen.getByRole("tab", { name: "通知設定" });
    await user.click(notificationTab);

    expect(notificationTab).toHaveAttribute("aria-selected", "true");
  });

  it("カレンダー同期タブに切り替えできる", async () => {
    const user = userEvent.setup();
    renderWithProviders();

    await screen.findByRole("tab", { name: "グループ基本設定" });

    const calendarTab = screen.getByRole("tab", {
      name: "Google カレンダー同期",
    });
    await user.click(calendarTab);

    expect(calendarTab).toHaveAttribute("aria-selected", "true");
  });

  /* Owner 認証チェックのテスト */
  describe("Owner アクセス制御", () => {
    it("未認証ユーザーにはアクセス拒否メッセージが表示される", async () => {
      mockUseCurrentUser.mockReturnValue({
        selectedUserId: null,
        isAuthenticated: false,
        isLoading: false,
        selectUser: vi.fn(),
      });

      renderWithProviders();

      const warning = await screen.findByText(
        "この設定ページは Owner のみアクセスできます。",
      );
      expect(warning).toBeInTheDocument();

      /* ログイン案内が表示される */
      expect(
        screen.getByText("設定を変更するには Google 認証でログインしてください。"),
      ).toBeInTheDocument();

      /* スケジュールページへの戻りリンクが表示される */
      expect(
        screen.getByText("スケジュールページに戻る"),
      ).toBeInTheDocument();
    });

    it("認証済みだが Owner でないユーザーにはアクセス拒否メッセージが表示される", async () => {
      mockUseCurrentUser.mockReturnValue({
        selectedUserId: 99,
        isAuthenticated: true,
        isLoading: false,
        selectUser: vi.fn(),
      });

      renderWithProviders();

      const warning = await screen.findByText(
        "この設定ページは Owner のみアクセスできます。",
      );
      expect(warning).toBeInTheDocument();

      /* 認証済みなのでログイン案内は表示されない */
      expect(
        screen.queryByText("設定を変更するには Google 認証でログインしてください。"),
      ).not.toBeInTheDocument();
    });

    it("認証確認中はローディング表示がされる", () => {
      mockUseCurrentUser.mockReturnValue({
        selectedUserId: null,
        isAuthenticated: false,
        isLoading: true,
        selectUser: vi.fn(),
      });

      renderWithProviders();

      expect(screen.getByText("読み込み中...")).toBeInTheDocument();
    });

    it("認証済み Owner はタブが表示される", async () => {
      /* デフォルトの mockUseCurrentUser は認証済み Owner */
      renderWithProviders();

      await screen.findByRole("tab", { name: "グループ基本設定" });

      expect(screen.getByText("グループ設定")).toBeInTheDocument();
      expect(screen.getByRole("tab", { name: "グループ基本設定" })).toBeInTheDocument();
      expect(screen.getByRole("tab", { name: "閾値設定" })).toBeInTheDocument();
    });
  });
});
