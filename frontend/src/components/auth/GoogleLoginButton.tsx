/**
 * Google ログインボタンコンポーネント
 *
 * 🔒 付きユーザー選択時に表示される Google OAuth 認証開始ボタン。
 * クリックすると Google OAuth 認証フローを開始する。
 *
 * 要件: 1.4, 1.5
 */
import { Button, CircularProgress } from "@mui/material";
import GoogleIcon from "@mui/icons-material/Google";
import { useTranslation } from "react-i18next";

interface GoogleLoginButtonProps {
  /** ボタンクリック時のコールバック */
  onClick?: () => void;
  /** ローディング状態 */
  loading?: boolean;
  /** ボタン無効化 */
  disabled?: boolean;
}

export default function GoogleLoginButton({
  onClick,
  loading = false,
  disabled = false,
}: GoogleLoginButtonProps) {
  const { t } = useTranslation();

  /** Google OAuth 認証フローを開始する */
  const handleClick = () => {
    if (onClick) {
      onClick();
      return;
    }
    /* デフォルト: OAuth エンドポイントにリダイレクト */
    window.location.href = "/oauth/google";
  };

  return (
    <Button
      variant="contained"
      startIcon={loading ? <CircularProgress size={20} color="inherit" /> : <GoogleIcon />}
      onClick={handleClick}
      disabled={disabled || loading}
      sx={{ textTransform: "none" }}
    >
      {loading ? t("common.loading") : t("auth.loginWithGoogle")}
    </Button>
  );
}
