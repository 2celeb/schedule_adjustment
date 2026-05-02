/**
 * AdPlacement コンポーネントのユニットテスト
 *
 * 要件: 9.1, 9.2, 9.3, 9.4, 9.6
 */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { render, screen } from "@testing-library/react";
import { ThemeProvider, createTheme } from "@mui/material";
import AdPlacement from "@/components/ads/AdPlacement";

/**
 * MUI の useMediaQuery をモックして、デスクトップ/モバイルの切り替えをテストする。
 * matchMedia のモックで画面サイズをシミュレートする。
 */
const theme = createTheme();

/** テスト用ラッパー */
function renderWithTheme(ui: React.ReactElement) {
  return render(<ThemeProvider theme={theme}>{ui}</ThemeProvider>);
}

/** matchMedia のモック設定 */
function mockMatchMedia(matches: boolean) {
  Object.defineProperty(window, "matchMedia", {
    writable: true,
    value: vi.fn().mockImplementation((query: string) => ({
      matches,
      media: query,
      onchange: null,
      addListener: vi.fn(),
      removeListener: vi.fn(),
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      dispatchEvent: vi.fn(),
    })),
  });
}

describe("AdPlacement", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe("広告の ON/OFF 制御（要件 9.6）", () => {
    beforeEach(() => {
      /* デスクトップとして設定 */
      mockMatchMedia(false);
    });

    it("adEnabled=false の場合は何も表示しない", () => {
      renderWithTheme(
        <AdPlacement adEnabled={false} testMode />,
      );

      expect(
        screen.queryByTestId("ad-placement-desktop"),
      ).not.toBeInTheDocument();
      expect(
        screen.queryByTestId("ad-placement-mobile"),
      ).not.toBeInTheDocument();
    });

    it("adEnabled=true の場合は広告が表示される", () => {
      renderWithTheme(
        <AdPlacement adEnabled testMode />,
      );

      expect(
        screen.getByTestId("ad-placement-desktop"),
      ).toBeInTheDocument();
    });
  });

  describe("デスクトップ表示（要件 9.1）", () => {
    beforeEach(() => {
      /* デスクトップ: breakpoints.down("sm") が false */
      mockMatchMedia(false);
    });

    it("デスクトップではヘッダー位置にバナー広告が表示される", () => {
      renderWithTheme(
        <AdPlacement adEnabled testMode />,
      );

      expect(
        screen.getByTestId("ad-placement-desktop"),
      ).toBeInTheDocument();
      expect(
        screen.queryByTestId("ad-placement-mobile"),
      ).not.toBeInTheDocument();
    });

    it("デスクトップでは isEditing の影響を受けない", () => {
      renderWithTheme(
        <AdPlacement adEnabled isEditing testMode />,
      );

      /* デスクトップ広告は入力中でも表示される */
      expect(
        screen.getByTestId("ad-placement-desktop"),
      ).toBeInTheDocument();
    });
  });

  describe("モバイル表示（要件 9.2）", () => {
    beforeEach(() => {
      /* モバイル: breakpoints.down("sm") が true */
      mockMatchMedia(true);
    });

    it("モバイルではフッター固定バナー広告が表示される", () => {
      renderWithTheme(
        <AdPlacement adEnabled testMode />,
      );

      expect(
        screen.getByTestId("ad-placement-mobile"),
      ).toBeInTheDocument();
      expect(
        screen.queryByTestId("ad-placement-desktop"),
      ).not.toBeInTheDocument();
    });

    it("モバイルのフッター広告は固定位置に配置される", () => {
      renderWithTheme(
        <AdPlacement adEnabled testMode />,
      );

      const mobileAd = screen.getByTestId("ad-placement-mobile");
      expect(mobileAd).toHaveStyle({ position: "fixed", bottom: "0px" });
    });
  });

  describe("入力中の広告制御（要件 9.3, 9.4）", () => {
    beforeEach(() => {
      /* モバイルとして設定 */
      mockMatchMedia(true);
    });

    it("isEditing=false の場合はモバイルフッター広告が表示される", () => {
      renderWithTheme(
        <AdPlacement adEnabled isEditing={false} testMode />,
      );

      const mobileAd = screen.getByTestId("ad-placement-mobile");
      expect(mobileAd).not.toHaveStyle({ display: "none" });
    });

    it("isEditing=true の場合はモバイルフッター広告が非表示になる", () => {
      renderWithTheme(
        <AdPlacement adEnabled isEditing testMode />,
      );

      const mobileAd = screen.getByTestId("ad-placement-mobile");
      expect(mobileAd).toHaveStyle({ display: "none" });
    });
  });

  describe("広告スロット ID の設定", () => {
    beforeEach(() => {
      mockMatchMedia(false);
    });

    it("カスタムの desktopAdSlot が AdBanner に渡される", () => {
      renderWithTheme(
        <AdPlacement
          adEnabled
          desktopAdSlot="custom-desktop-slot"
          testMode
        />,
      );

      /* テストモードではプレースホルダーが表示される */
      expect(
        screen.getByTestId("ad-banner-placeholder"),
      ).toBeInTheDocument();
    });

    it("カスタムの mobileAdSlot が AdBanner に渡される", () => {
      mockMatchMedia(true);
      renderWithTheme(
        <AdPlacement
          adEnabled
          mobileAdSlot="custom-mobile-slot"
          testMode
        />,
      );

      expect(
        screen.getByTestId("ad-banner-placeholder"),
      ).toBeInTheDocument();
    });
  });
});
