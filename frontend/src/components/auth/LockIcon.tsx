/**
 * 🔒 アイコンコンポーネント
 *
 * MUI の Lock アイコンをラップした再利用可能なコンポーネント。
 * Google 認証が必要なユーザーを示すために使用する。
 *
 * 要件: 1.4, 1.5
 */
import MuiLockIcon from "@mui/icons-material/Lock";
import { useTranslation } from "react-i18next";

interface LockIconProps {
  /** アイコンサイズ（px）。デフォルト: 14 */
  size?: number;
}

export default function LockIcon({ size = 14 }: LockIconProps) {
  const { t } = useTranslation();

  return (
    <MuiLockIcon
      sx={{ fontSize: size }}
      aria-label={t("member.authLocked")}
    />
  );
}
