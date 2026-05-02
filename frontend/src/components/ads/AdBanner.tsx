/**
 * 広告バナーコンポーネント（Google AdSense 連携）
 *
 * Google AdSense のスクリプトを読み込み、広告ユニットを表示する。
 * - adSlot: AdSense の広告ユニット ID
 * - adFormat: 広告フォーマット（auto / horizontal / vertical）
 * - fullWidthResponsive: レスポンシブ対応の全幅表示
 *
 * 要件: 9.5
 */
import { useEffect, useRef } from "react";
import { Box, Typography } from "@mui/material";
import { useTranslation } from "react-i18next";

/** AdSense の window 拡張型 */
declare global {
  interface Window {
    adsbygoogle?: Record<string, unknown>[];
  }
}

/** AdBanner の props */
export interface AdBannerProps {
  /** AdSense 広告ユニット ID（例: "1234567890"） */
  adSlot: string;
  /**
   * 広告フォーマット
   * - "auto": 自動サイズ調整（デフォルト）
   * - "horizontal": 横長バナー
   * - "vertical": 縦長バナー
   */
  adFormat?: "auto" | "horizontal" | "vertical";
  /** レスポンシブ対応の全幅表示（デフォルト: true） */
  fullWidthResponsive?: boolean;
  /** テスト用: 広告の代わりにプレースホルダーを表示 */
  testMode?: boolean;
}

/**
 * Google AdSense 広告バナーコンポーネント
 *
 * AdSense スクリプトが読み込まれている環境では実際の広告を表示し、
 * 未読み込みの場合やテストモードではプレースホルダーを表示する。
 */
export default function AdBanner({
  adSlot,
  adFormat = "auto",
  fullWidthResponsive = true,
  testMode = false,
}: AdBannerProps) {
  const { t } = useTranslation();
  const adRef = useRef<HTMLModElement>(null);
  const pushed = useRef(false);

  useEffect(() => {
    /* テストモードでは AdSense を読み込まない */
    if (testMode) return;

    /* 同一インスタンスで二重 push しない */
    if (pushed.current) return;

    try {
      (window.adsbygoogle = window.adsbygoogle || []).push({});
      pushed.current = true;
    } catch {
      /* AdSense スクリプト未読み込み時は無視 */
    }
  }, [testMode]);

  /* テストモード: プレースホルダー表示 */
  if (testMode) {
    return (
      <Box
        data-testid="ad-banner-placeholder"
        sx={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          bgcolor: "grey.100",
          border: "1px dashed",
          borderColor: "grey.300",
          borderRadius: 1,
          minHeight: 90,
          p: 1,
        }}
      >
        <Typography variant="caption" color="text.secondary">
          {t("ad.label")}
        </Typography>
      </Box>
    );
  }

  return (
    <Box data-testid="ad-banner" sx={{ overflow: "hidden" }}>
      <ins
        ref={adRef}
        className="adsbygoogle"
        style={{ display: "block" }}
        data-ad-client={import.meta.env.VITE_ADSENSE_CLIENT_ID || ""}
        data-ad-slot={adSlot}
        data-ad-format={adFormat}
        data-full-width-responsive={fullWidthResponsive ? "true" : "false"}
      />
    </Box>
  );
}
