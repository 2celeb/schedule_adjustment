# Active Record 暗号化の設定
# Rails 7.0+ の encrypts 機能で google_oauth_token 等を暗号化するために必要
#
# 本番環境では環境変数から暗号化キーを読み込む
# 開発・テスト環境ではデフォルト値を使用
Rails.application.configure do
  config.active_record.encryption.primary_key = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY', 'dev-primary-key-for-local-use-only-32chars!')
  config.active_record.encryption.deterministic_key = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY', 'dev-deterministic-key-local-only-32chars!')
  config.active_record.encryption.key_derivation_salt = ENV.fetch('ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT', 'dev-key-derivation-salt-for-local-use!')
end
