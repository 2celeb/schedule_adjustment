import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import ja from "./ja.json";
import en from "./en.json";

/**
 * i18n 初期設定
 *
 * - デフォルト言語: 日本語（ja）
 * - フォールバック: 日本語
 * - 補間エスケープ: React が XSS 対策を行うため無効化
 */
i18n.use(initReactI18next).init({
  resources: {
    ja: { translation: ja },
    en: { translation: en },
  },
  lng: "ja",
  fallbackLng: "ja",
  interpolation: {
    escapeValue: false,
  },
});

export default i18n;
