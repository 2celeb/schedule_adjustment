/**
 * ルートコンポーネント
 *
 * react-router-dom の Routes / Route でページルーティングを定義する。
 * - /:share_token → SchedulePage（メインスケジュールページ）
 * - /oauth/callback → OAuthCallbackPage（OAuth コールバック処理）
 * - / → ランディングページ（ウェルカムメッセージ）
 */
import { Routes, Route } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Typography, Container } from "@mui/material";
import SchedulePage from "@/pages/SchedulePage";
import OAuthCallbackPage from "@/pages/OAuthCallbackPage";

/** ランディングページ（シンプルなウェルカムメッセージ） */
function LandingPage() {
  const { t } = useTranslation();

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <Typography variant="h4" component="h1">
        {t("app.title")}
      </Typography>
    </Container>
  );
}

function App() {
  return (
    <Routes>
      <Route path="/oauth/callback" element={<OAuthCallbackPage />} />
      <Route path="/:share_token" element={<SchedulePage />} />
      <Route path="/" element={<LandingPage />} />
    </Routes>
  );
}

export default App;
