/**
 * Vitest テストセットアップ
 *
 * jsdom 環境で React Testing Library を使用するための設定。
 * i18n を初期化して翻訳が正しく動作するようにする。
 */
import "@testing-library/jest-dom";
import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import ja from "@/i18n/ja.json";
import en from "@/i18n/en.json";

/**
 * テスト用 i18n 初期化
 * initImmediate: false で同期的に初期化する
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
  initImmediate: false,
});
