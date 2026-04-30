import { createTheme } from "@mui/material/styles";

/**
 * MUI テーマ設定
 *
 * カラーパレット:
 * - primary: スケジュール調整ツールのメインカラー（青系）
 * - secondary: アクセントカラー（紫系）
 * - success: 参加可能（○）の緑
 * - warning: 未定・条件付き（△）の黄
 * - error: 参加不可（×）の赤
 *
 * フォント:
 * - 日本語環境を考慮し、Noto Sans JP を優先指定
 */
export const theme = createTheme({
  palette: {
    primary: {
      main: "#1976d2",
      light: "#42a5f5",
      dark: "#1565c0",
    },
    secondary: {
      main: "#7b1fa2",
      light: "#ab47bc",
      dark: "#6a1b9a",
    },
    success: {
      main: "#2e7d32",
      light: "#4caf50",
      dark: "#1b5e20",
    },
    warning: {
      main: "#ed6c02",
      light: "#ff9800",
      dark: "#e65100",
    },
    error: {
      main: "#d32f2f",
      light: "#ef5350",
      dark: "#c62828",
    },
    background: {
      default: "#fafafa",
      paper: "#ffffff",
    },
  },
  typography: {
    fontFamily: [
      '"Noto Sans JP"',
      '"Roboto"',
      '"Helvetica Neue"',
      "Arial",
      "sans-serif",
    ].join(","),
  },
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        body: {
          // Tailwind CSS との共存のため、MUI のデフォルトスタイルを維持
        },
      },
    },
    MuiButton: {
      defaultProps: {
        disableElevation: true,
      },
      styleOverrides: {
        root: {
          textTransform: "none",
        },
      },
    },
    MuiTooltip: {
      defaultProps: {
        arrow: true,
      },
    },
  },
});
