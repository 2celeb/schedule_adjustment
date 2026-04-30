# 参加可否変更履歴モデル
# 変更操作の抑止力として、User-Agent・IP・地域情報を記録
class AvailabilityLog < ApplicationRecord
  belongs_to :availability
  belongs_to :user
end
