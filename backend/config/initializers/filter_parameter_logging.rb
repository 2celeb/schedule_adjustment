# ログに出力しないパラメータを設定
# パスワード、トークン等の機密情報をフィルタリング
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  :google_oauth_token
]
