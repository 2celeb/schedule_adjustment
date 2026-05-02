/**
 * 広告配置制御コンポーネント
 *
 * デバイスサイズに応じて広告の配置を制御する:
 * - デスクトップ: ヘッダーまたはサイドバーにバナー広告を表示
 * - モバイル: フッター固定バナー広告を表示
 *
 * 入力中（isEditing=true）はポップアップ/インタースティシャル広告を表示しない。
 * グループの ad_enabled 設定に応じて広告の ON/OFF を制御する。
 *
 * 要件: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6
 */
import { Box, useMediaQuery, useTheme } from "@mui/material";
import AdBanner from "./AdBanner";

/** AdPlacement の props */
export interface AdPlacementProps {
  /** 広告表示が有効かどうか（グループの ad_enabled に対応） */
  adEnabled: boolean;
  /** ユーザーが Availability_Status を入力中かどうか */
  isEditing?: boolean;
  /** AdSense 広告ユニット ID（デスクトップ用） */
  desktopAdSlot?: string;
  /** AdSense 広告ユニット ID（モバイル用） */
  mobileAdSlot?: string;
  /** テスト用: 広告の代わりにプレースホルダーを表示 */
  testMode?: boolean;
}

/** デフォルトの広告スロット ID（環境変数から取得、未設定時は空文字） */
const DEFAULT_DESKTOP_AD_SLOT =
  import.meta.env.VITE_ADSENSE_DESKTOP_SLOT || "desktop-default";
const DEFAULT_MOBILE_AD_SLOT =
  import.meta.env.VITE_ADSENSE_MOBILE_SLOT || "mobile-default";

/**
 * 広告配置制御コンポーネント
 *
 * - ad_enabled=false の場合は何も表示しない
 * - isEditing=true の場合はモバイルフッター広告を非表示にする
 *   （カレンダー操作を妨げないため）
 * - デスクトップではヘッダー位置にバナー広告を表示
 * - モバイルではフッター固定バナー広告を表示
 */
export default function AdPlacement({
  adEnabled,
  isEditing = false,
  desktopAdSlot = DEFAULT_DESKTOP_AD_SLOT,
  mobileAdSlot = DEFAULT_MOBILE_AD_SLOT,
  testMode = false,
}: AdPlacementProps) {
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down("sm"));

  /* 広告が無効の場合は何も表示しない */
  if (!adEnabled) {
    return null;
  }

  /* モバイル: フッター固定バナー */
  if (isMobile) {
    return (
      <Box
        data-testid="ad-placement-mobile"
        sx={{
          position: "fixed",
          bottom: 0,
          left: 0,
          right: 0,
          zIndex: theme.zIndex.appBar - 1,
          bgcolor: "background.paper",
          borderTop: "1px solid",
          borderColor: "divider",
          /* 入力中はフッター広告を非表示にする（操作性を妨げないため） */
          display: isEditing ? "none" : "block",
          /* フッター広告分のパディングを確保するため、body にマージンを追加する必要がある */
        }}
      >
        <AdBanner
          adSlot={mobileAdSlot}
          adFormat="horizontal"
          fullWidthResponsive
          testMode={testMode}
        />
      </Box>
    );
  }

  /* デスクトップ: ヘッダー位置のバナー広告 */
  return (
    <Box
      data-testid="ad-placement-desktop"
      sx={{
        mb: 2,
        /* カレンダーの操作性を妨げない位置に配置 */
      }}
    >
      <AdBanner
        adSlot={desktopAdSlot}
        adFormat="horizontal"
        fullWidthResponsive
        testMode={testMode}
      />
    </Box>
  );
}
