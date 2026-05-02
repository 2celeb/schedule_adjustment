/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Rails API のベース URL（例: http://localhost/api） */
  readonly VITE_API_BASE_URL: string;
  /** Google AdSense クライアント ID（例: ca-pub-1234567890） */
  readonly VITE_ADSENSE_CLIENT_ID?: string;
  /** AdSense デスクトップ用広告スロット ID */
  readonly VITE_ADSENSE_DESKTOP_SLOT?: string;
  /** AdSense モバイル用広告スロット ID */
  readonly VITE_ADSENSE_MOBILE_SLOT?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
