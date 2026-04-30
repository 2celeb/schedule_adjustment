# Discord 設定モデル
# グループごとの Discord サーバー連携設定
class DiscordConfig < ApplicationRecord
  belongs_to :group

  # バリデーション: 1グループにつき1つの Discord 設定
  validates :group_id, uniqueness: { message: 'には既に Discord 設定が存在します' }
end
