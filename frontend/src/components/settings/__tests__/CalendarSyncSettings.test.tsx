/**
 * CalendarSyncSettings コンポーネントのユニットテスト
 *
 * 要件: 7.1, 7.5, 7.6, 7.11
 */
import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import type { ReactNode } from "react";
import CalendarSyncSettings from "@/components/settings/CalendarSyncSettings";

/** react-i18next をモック */
vi.mock("react-i18next", () => ({
  useTranslation: () => ({
    t: (key: string, fallback?: string) => {
      const translations: Record<string, string> = {
        "calendar.sync": "Google カレンダー同期",
        "calendar.syncNow": "今すぐ同期",
        "calendar.disconnect": "Google 連携を解除",
        "calendar.syncSuccess": "同期をキューに追加しました",
        "calendar.syncError": "同期に失敗しました",
        "calendar.disconnectConfirm": "Google 連携を解除しますか？",
        "calendar.disconnectSuccess": "Google 連携を解除しました",
        "calendar.disconnectError": "連携解除に失敗しました",
        "calendar.notConnected": "Google カレンダーに接続されていません",
        "calendar.connected": "Google カレンダーに接続中",
        "calendar.patternLabel": "連携パターン",
        "calendar.pattern.none": "連携なし",
        "calendar.pattern.freebusyOnly": "予定枠のみ",
        "calendar.pattern.freebusyAndWrite": "予定枠＋書き込み",
        "common.cancel": "キャンセル",
        "common.confirm": "確認",
      };
      return translations[key] ?? fallback ?? key;
    },
  }),
}));

/** useCalendarSync フックをモック */
const mockTriggerSync = vi.fn();
const mockDisconnectGoogle = vi.fn();
const mockResetSyncStatus = vi.fn();
const mockResetDisconnectStatus = vi.fn();

vi.mock("@/hooks/useCalendarSync", () => ({
  useCalendarSync: () => ({
    triggerSync: mockTriggerSync,
    disconnectGoogle: mockDisconnectGoogle,
    isSyncing: false,
    isDisconnecting: false,
    syncSuccess: false,
    syncError: null,
    disconnectSuccess: false,
    disconnectError: null,
    resetSyncStatus: mockResetSyncStatus,
    resetDisconnectStatus: mockResetDisconnectStatus,
  }),
}));

/** テスト用の QueryClient ラッパー */
function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
    },
  });
  return function Wrapper({ children }: { children: ReactNode }) {
    return (
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    );
  };
}

const defaultProps: {
  shareToken: string;
  userId: number;
  googleCalendarScope: string | null;
  isGoogleConnected: boolean;
} = {
  shareToken: "abc123",
  userId: 42,
  googleCalendarScope: "calendar.freebusy.readonly",
  isGoogleConnected: true,
};

function renderComponent(props = defaultProps) {
  const Wrapper = createWrapper();
  return render(
    <Wrapper>
      <CalendarSyncSettings {...props} />
    </Wrapper>,
  );
}

describe("CalendarSyncSettings", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("タイトルが表示される", () => {
    renderComponent();
    expect(screen.getByText("Google カレンダー同期")).toBeInTheDocument();
  });

  it("Google 接続中の場合は接続中メッセージが表示される", () => {
    renderComponent();
    expect(
      screen.getByText("Google カレンダーに接続中"),
    ).toBeInTheDocument();
  });

  it("Google 未接続の場合は未接続メッセージが表示される", () => {
    renderComponent({
      ...defaultProps,
      isGoogleConnected: false,
      googleCalendarScope: null,
    });
    expect(
      screen.getByText("Google カレンダーに接続されていません"),
    ).toBeInTheDocument();
  });

  it("連携パターンのラジオボタンが表示される", () => {
    renderComponent();
    expect(screen.getByText("連携なし")).toBeInTheDocument();
    expect(screen.getByText("予定枠のみ")).toBeInTheDocument();
    expect(screen.getByText("予定枠＋書き込み")).toBeInTheDocument();
  });

  it("freebusy スコープの場合は「予定枠のみ」が選択される", () => {
    renderComponent();
    const freebusyRadio = screen.getByLabelText("予定枠のみ");
    expect(freebusyRadio).toBeChecked();
  });

  it("calendar スコープの場合は「予定枠＋書き込み」が選択される", () => {
    renderComponent({
      ...defaultProps,
      googleCalendarScope: "calendar",
    });
    const writeRadio = screen.getByLabelText("予定枠＋書き込み");
    expect(writeRadio).toBeChecked();
  });

  it("未連携の場合は「連携なし」が選択される", () => {
    renderComponent({
      ...defaultProps,
      isGoogleConnected: false,
      googleCalendarScope: null,
    });
    const noneRadio = screen.getByLabelText("連携なし");
    expect(noneRadio).toBeChecked();
  });

  it("「今すぐ同期」ボタンをクリックすると triggerSync が呼ばれる", async () => {
    const user = userEvent.setup();
    renderComponent();

    await user.click(screen.getByText("今すぐ同期"));
    expect(mockTriggerSync).toHaveBeenCalledWith("abc123");
  });

  it("未接続の場合は「今すぐ同期」ボタンが無効になる", () => {
    renderComponent({
      ...defaultProps,
      isGoogleConnected: false,
      googleCalendarScope: null,
    });

    expect(screen.getByText("今すぐ同期")).toBeDisabled();
  });

  it("未接続の場合は「Google 連携を解除」ボタンが無効になる", () => {
    renderComponent({
      ...defaultProps,
      isGoogleConnected: false,
      googleCalendarScope: null,
    });

    expect(screen.getByText("Google 連携を解除")).toBeDisabled();
  });

  it("「Google 連携を解除」ボタンで確認ダイアログが表示される", async () => {
    const user = userEvent.setup();
    renderComponent();

    await user.click(screen.getByText("Google 連携を解除"));

    expect(
      screen.getByText("Google 連携を解除しますか？"),
    ).toBeInTheDocument();
  });

  it("確認ダイアログで「確認」をクリックすると disconnectGoogle が呼ばれる", async () => {
    const user = userEvent.setup();
    renderComponent();

    await user.click(screen.getByText("Google 連携を解除"));
    await user.click(screen.getByText("確認"));

    expect(mockDisconnectGoogle).toHaveBeenCalledWith(42);
  });

  it("確認ダイアログで「キャンセル」をクリックするとダイアログが閉じる", async () => {
    const user = userEvent.setup();
    renderComponent();

    await user.click(screen.getByText("Google 連携を解除"));
    expect(
      screen.getByText("Google 連携を解除しますか？"),
    ).toBeInTheDocument();

    await user.click(screen.getByText("キャンセル"));

    await waitFor(() => {
      expect(
        screen.queryByText("Google 連携を解除しますか？"),
      ).not.toBeInTheDocument();
    });
  });
});
