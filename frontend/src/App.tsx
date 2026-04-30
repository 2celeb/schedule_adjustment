import { useTranslation } from "react-i18next";
import { Typography, Container } from "@mui/material";

function App() {
  const { t } = useTranslation();

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <Typography variant="h4" component="h1">
        {t("app.title")}
      </Typography>
    </Container>
  );
}

export default App;
