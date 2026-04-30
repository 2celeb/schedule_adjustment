# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AvailabilityLog, type: :model do
  describe 'リレーション' do
    it { expect(described_class.reflect_on_association(:availability).macro).to eq :belongs_to }
    it { expect(described_class.reflect_on_association(:user).macro).to eq :belongs_to }
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効なレコードを作成する' do
      expect(build(:availability_log)).to be_valid
    end
  end
end
