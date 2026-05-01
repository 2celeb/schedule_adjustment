# frozen_string_literal: true

# リクエストスコープの情報を保持するスレッドローカルストア
# コントローラーからモデル層にリクエスト情報を渡すために使用する
#
# 使用例:
#   Current.user_agent = request.user_agent
#   Current.ip_address = request.remote_ip
class Current < ActiveSupport::CurrentAttributes
  # リクエスト元の User-Agent 文字列
  attribute :user_agent

  # リクエスト元の IP アドレス
  attribute :ip_address
end
