---
inclusion: always
---

# 改行コードルール

## 基本方針

- 本プロジェクトの全ファイルは **LF（`\n`）** を改行コードとして使用する
- CRLF（`\r\n`）は使用しない

## ファイル作成・編集後の対応

- `fsWrite` や `fsAppend` でファイルを作成・編集した後は、必ず `sed -i 's/\r$//'` で CRLF を LF に変換すること
- 複数ファイルを作成した場合は、まとめて一括変換してよい

```bash
# 例: 単一ファイルの変換
sed -i 's/\r$//' path/to/file

# 例: 複数ファイルの一括変換
sed -i 's/\r$//' file1.ts file2.ts file3.tsx
```

## 理由

- Kiro のファイル書き込みツールが Windows 環境（WSL 含む）で CRLF を出力する場合がある
- Git で `warning: CRLF will be replaced by LF` の警告が発生する原因となる
- Linux コンテナ（Docker）での実行時に問題を引き起こす可能性がある
