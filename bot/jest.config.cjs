/** @type {import('jest').Config} */
const config = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src"],
  testMatch: ["**/__tests__/**/*.test.ts"],
  moduleNameMapper: {
    // ESM の .js 拡張子付きインポートを .ts に解決する
    "^(\\.{1,2}/.*)\\.js$": "$1",
  },
  transform: {
    "^.+\\.ts$": [
      "ts-jest",
      {
        useESM: false,
        tsconfig: "tsconfig.json",
        diagnostics: {
          ignoreCodes: [151002],
        },
      },
    ],
  },
  clearMocks: true,
  restoreMocks: true,
};

module.exports = config;
