/**
 * AdBanner コンポーネントのユニットテスト
 *
 * 要件: 9.5
 */
import { describe, it, expect, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import AdBanner from "@/components/ads/AdBanner";

describe("AdBanner", () => {
  beforeEach(() => {
    /* adsbygoogle 配列をリセット */
    window.adsbygoogle = [];
  });

  it("テストモードでプレースホルダーが表示される", () => {
    render(<AdBanner adSlot="test-slot" testMode />);

    expect(screen.getByTestId("ad-banner-placeholder")).toBeInTheDocument();
    expect(screen.getByText("広告")).toBeInTheDocument();
  });

  it("テストモードでは adsbygoogle に push されない", () => {
    window.adsbygoogle = [];
    render(<AdBanner adSlot="test-slot" testMode />);

    expect(window.adsbygoogle).toHaveLength(0);
  });

  it("通常モードで ins 要素が表示される", () => {
    render(<AdBanner adSlot="test-slot-123" />);

    expect(screen.getByTestId("ad-banner")).toBeInTheDocument();
    const ins = screen.getByTestId("ad-banner").querySelector("ins");
    expect(ins).toBeInTheDocument();
    expect(ins).toHaveAttribute("data-ad-slot", "test-slot-123");
  });

  it("adFormat が正しく設定される", () => {
    render(<AdBanner adSlot="test-slot" adFormat="horizontal" />);

    const ins = screen.getByTestId("ad-banner").querySelector("ins");
    expect(ins).toHaveAttribute("data-ad-format", "horizontal");
  });

  it("デフォルトの adFormat は auto", () => {
    render(<AdBanner adSlot="test-slot" />);

    const ins = screen.getByTestId("ad-banner").querySelector("ins");
    expect(ins).toHaveAttribute("data-ad-format", "auto");
  });

  it("fullWidthResponsive が true の場合、data-full-width-responsive が true", () => {
    render(<AdBanner adSlot="test-slot" fullWidthResponsive />);

    const ins = screen.getByTestId("ad-banner").querySelector("ins");
    expect(ins).toHaveAttribute("data-full-width-responsive", "true");
  });

  it("fullWidthResponsive が false の場合、data-full-width-responsive が false", () => {
    render(
      <AdBanner adSlot="test-slot" fullWidthResponsive={false} />,
    );

    const ins = screen.getByTestId("ad-banner").querySelector("ins");
    expect(ins).toHaveAttribute("data-full-width-responsive", "false");
  });

  it("通常モードで adsbygoogle に push される", () => {
    window.adsbygoogle = [];
    render(<AdBanner adSlot="test-slot" />);

    expect(window.adsbygoogle.length).toBeGreaterThanOrEqual(1);
  });

  it("テストモードのプレースホルダーに適切なスタイルが適用される", () => {
    render(<AdBanner adSlot="test-slot" testMode />);

    const placeholder = screen.getByTestId("ad-banner-placeholder");
    expect(placeholder).toBeInTheDocument();
    /* プレースホルダーが表示されていることを確認 */
    expect(placeholder).toBeVisible();
  });
});
