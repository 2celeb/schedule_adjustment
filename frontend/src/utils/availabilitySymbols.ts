/**
 * ロケール別の参加可否記号マッピング
 *
 * 要件 4.12: ロケール設定により記号を切り替え可能とする
 *   - 日本語: ○ / △ / × / −
 *   - 英語:   ✓ / ? / ✗ / −
 *
 * status 値の定義:
 *   1    = 参加可能（ok）
 *   0    = 未定・条件付き（maybe）
 *   -1   = 参加不可（ng）
 *   null = 未入力（none）
 */

/** サポートするロケール */
export type SupportedLocale = "ja" | "en";

/** Availability の status 値（DB 格納値） */
export type AvailabilityStatus = 1 | 0 | -1 | null;

/** 記号セットの型定義 */
interface SymbolSet {
  ok: string;
  maybe: string;
  ng: string;
  none: string;
}

/** ロケールごとの記号マッピング */
const symbolMap: Record<SupportedLocale, SymbolSet> = {
  ja: {
    ok: "○",
    maybe: "△",
    ng: "×",
    none: "−",
  },
  en: {
    ok: "✓",
    maybe: "?",
    ng: "✗",
    none: "−",
  },
};

/**
 * status 値を内部キーに変換する
 */
function statusToKey(status: AvailabilityStatus): keyof SymbolSet {
  switch (status) {
    case 1:
      return "ok";
    case 0:
      return "maybe";
    case -1:
      return "ng";
    default:
      return "none";
  }
}

/**
 * ロケールと status 値から表示記号を返す
 *
 * @param locale - ロケール（"ja" または "en"）
 * @param status - Availability の status 値（1, 0, -1, null）
 * @returns 対応する記号文字列
 *
 * @example
 * ```ts
 * getAvailabilitySymbol("ja", 1);    // "○"
 * getAvailabilitySymbol("en", 1);    // "✓"
 * getAvailabilitySymbol("ja", -1);   // "×"
 * getAvailabilitySymbol("en", null); // "−"
 * ```
 */
export function getAvailabilitySymbol(
  locale: SupportedLocale,
  status: AvailabilityStatus,
): string {
  const symbols = symbolMap[locale] ?? symbolMap.ja;
  return symbols[statusToKey(status)];
}

/**
 * ロケールに対応する記号セット全体を返す
 *
 * @param locale - ロケール（"ja" または "en"）
 * @returns 記号セット { ok, maybe, ng, none }
 */
export function getSymbolSet(locale: SupportedLocale): SymbolSet {
  return symbolMap[locale] ?? symbolMap.ja;
}

/**
 * status 値に対応する色を返す（MUI テーマカラー用）
 *
 * 要件 4.11: 色分け表示（緑=○、黄=△、赤=×、グレー=−）
 */
export function getAvailabilityColor(status: AvailabilityStatus): string {
  switch (status) {
    case 1:
      return "#4caf50"; // 緑
    case 0:
      return "#ff9800"; // 黄
    case -1:
      return "#f44336"; // 赤
    default:
      return "#9e9e9e"; // グレー
  }
}
