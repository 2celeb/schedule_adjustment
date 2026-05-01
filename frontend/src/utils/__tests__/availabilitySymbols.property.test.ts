/**
 * ロケール記号変換のプロパティテスト
 *
 * Feature: schedule-management-tool, Property 10: ロケール記号切り替え
 *
 * 任意のロケール（ja/en）と status 値（1, 0, -1, null）の組み合わせで
 * 正しい記号が返されることを検証する。
 *
 * Validates: 要件 4.12
 */
import { describe, it, expect } from "vitest";
import * as fc from "fast-check";
import {
  getAvailabilitySymbol,
  getSymbolSet,
  getAvailabilityColor,
  type SupportedLocale,
  type AvailabilityStatus,
} from "../availabilitySymbols";

/** ロケールの Arbitrary */
const localeArb: fc.Arbitrary<SupportedLocale> = fc.constantFrom("ja", "en");

/** status 値の Arbitrary */
const statusArb: fc.Arbitrary<AvailabilityStatus> = fc.constantFrom(
  1,
  0,
  -1,
  null,
);

/** ロケールごとの期待される記号マッピング */
const expectedSymbols: Record<
  SupportedLocale,
  Record<string, string>
> = {
  ja: { "1": "○", "0": "△", "-1": "×", null: "−" },
  en: { "1": "✓", "0": "?", "-1": "✗", null: "−" },
};

describe("Property 10: ロケール記号切り替え", () => {
  it("任意のロケールと status の組み合わせで正しい記号が返される", () => {
    fc.assert(
      fc.property(localeArb, statusArb, (locale, status) => {
        const result = getAvailabilitySymbol(locale, status);
        const key = String(status);
        const expected = expectedSymbols[locale][key];

        expect(result).toBe(expected);
      }),
      { numRuns: 100 },
    );
  });

  it("返される記号は常に空文字列でない", () => {
    fc.assert(
      fc.property(localeArb, statusArb, (locale, status) => {
        const result = getAvailabilitySymbol(locale, status);

        expect(result).toBeTruthy();
        expect(result.length).toBeGreaterThan(0);
      }),
      { numRuns: 100 },
    );
  });

  it("同じロケールと status の組み合わせは常に同じ記号を返す（参照透過性）", () => {
    fc.assert(
      fc.property(localeArb, statusArb, (locale, status) => {
        const result1 = getAvailabilitySymbol(locale, status);
        const result2 = getAvailabilitySymbol(locale, status);

        expect(result1).toBe(result2);
      }),
      { numRuns: 100 },
    );
  });

  it("異なるロケール間で ok/maybe/ng の記号は異なる", () => {
    fc.assert(
      fc.property(
        fc.constantFrom<AvailabilityStatus>(1, 0, -1),
        (status) => {
          const jaSymbol = getAvailabilitySymbol("ja", status);
          const enSymbol = getAvailabilitySymbol("en", status);

          expect(jaSymbol).not.toBe(enSymbol);
        },
      ),
      { numRuns: 100 },
    );
  });

  it("未入力（null）の記号は全ロケールで共通（−）", () => {
    fc.assert(
      fc.property(localeArb, (locale) => {
        const result = getAvailabilitySymbol(locale, null);

        expect(result).toBe("−");
      }),
      { numRuns: 100 },
    );
  });

  it("同一ロケール内で ok/maybe/ng/none の記号は全て異なる", () => {
    fc.assert(
      fc.property(localeArb, (locale) => {
        const symbols = [1, 0, -1, null].map((s) =>
          getAvailabilitySymbol(locale, s as AvailabilityStatus),
        );
        const uniqueSymbols = new Set(symbols);

        expect(uniqueSymbols.size).toBe(4);
      }),
      { numRuns: 100 },
    );
  });

  it("getSymbolSet が返す記号セットと getAvailabilitySymbol の結果が一致する", () => {
    fc.assert(
      fc.property(localeArb, statusArb, (locale, status) => {
        const symbolFromFn = getAvailabilitySymbol(locale, status);
        const symbolSet = getSymbolSet(locale);

        const keyMap: Record<string, keyof typeof symbolSet> = {
          "1": "ok",
          "0": "maybe",
          "-1": "ng",
          null: "none",
        };
        const key = String(status);
        const symbolFromSet = symbolSet[keyMap[key] as keyof typeof symbolSet];

        expect(symbolFromFn).toBe(symbolFromSet);
      }),
      { numRuns: 100 },
    );
  });

  it("getAvailabilityColor は任意の status に対して有効な CSS カラーを返す", () => {
    fc.assert(
      fc.property(statusArb, (status) => {
        const color = getAvailabilityColor(status);

        // #RRGGBB 形式であること
        expect(color).toMatch(/^#[0-9a-f]{6}$/i);
      }),
      { numRuns: 100 },
    );
  });

  it("status ごとに異なる色が割り当てられている", () => {
    const colors = [1, 0, -1, null].map((s) =>
      getAvailabilityColor(s as AvailabilityStatus),
    );
    const uniqueColors = new Set(colors);

    expect(uniqueColors.size).toBe(4);
  });
});
