# frozen_string_literal: true

# 参加可否モデル
# メンバーの各日の参加可否状態（○/△/×/未入力）を管理
#
# 変更時には AvailabilityLog を自動作成し、変更履歴を記録する。
# リクエスト情報（User-Agent、IP アドレス）は Current 経由で取得する。
class Availability < ApplicationRecord
  belongs_to :user
  belongs_to :group
  has_many :availability_logs, dependent: :destroy

  # バリデーション
  validates :date, presence: true
  validates :status, inclusion: { in: [1, 0, -1] }, allow_nil: true
  validates :user_id, uniqueness: { scope: [:group_id, :date], message: 'はこのグループ・日付の組み合わせで既に登録されています' }

  # 変更履歴記録のコールバック
  # status または comment が変更された場合にのみ AvailabilityLog を作成する
  after_save :record_change_log, if: :should_record_log?

  private

  # 変更履歴を記録すべきかどうかを判定する
  # 新規作成時（status が nil でない場合）または status/comment の変更時に true
  def should_record_log?
    return !status.nil? if previously_new_record?

    saved_change_to_status? || saved_change_to_comment?
  end

  # 変更履歴を AvailabilityLog に記録する
  # Current から User-Agent と IP アドレスを取得し、GeoIpService で地域を推定する
  def record_change_log
    availability_logs.create!(
      user: user,
      old_status: previous_value_for(:status),
      new_status: status,
      old_comment: previous_value_for(:comment),
      new_comment: comment,
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      geo_region: GeoIpService.lookup(Current.ip_address)
    )
  end

  # 指定属性の変更前の値を取得する
  # 新規作成時は nil、更新時は saved_changes から取得（変更がなければ現在値）
  def previous_value_for(attr_name)
    return nil if previously_new_record?

    change = saved_changes[attr_name.to_s]
    change ? change[0] : public_send(attr_name)
  end
end
