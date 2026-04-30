/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Rails API のベース URL（例: http://localhost/api） */
  readonly VITE_API_BASE_URL: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
