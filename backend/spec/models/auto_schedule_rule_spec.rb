# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutoScheduleRule, type: :model do
  describe 'リレーション' do
    it { expect(described_class.reflect_on_association(:group).macro).to eq :belongs_to }
  end

  describe 'バリデーション' do
    describe 'max_days_per_week' do
      it 'nil を許可する' do
        rule = build(:auto_schedule_rule, max_days_per_week: nil)
        expect(rule).to be_valid
      end

      (1..7).each do |n|
        it "#{n} を許可する" do
          rule = build(:auto_schedule_rule, max_days_per_week: n)
          expect(rule).to be_valid
        end
      end

      it '0 を拒否する' do
        rule = build(:auto_schedule_rule, max_days_per_week: 0)
        expect(rule).not_to be_valid
        expect(rule.errors[:max_days_per_week]).to be_present
      end

      it '8 を拒否する' do
        rule = build(:auto_schedule_rule, max_days_per_week: 8)
        expect(rule).not_to be_valid
        expect(rule.errors[:max_days_per_week]).to be_present
      end
    end

    describe 'min_days_per_week' do
      it 'nil を許可する' do
        rule = build(:auto_schedule_rule, min_days_per_week: nil)
        expect(rule).to be_valid
      end

      it '0 を許可する' do
        rule = build(:auto_schedule_rule, min_days_per_week: 0)
        expect(rule).to be_valid
      end

      it '負の値を拒否する' do
        rule = build(:auto_schedule_rule, min_days_per_week: -1)
        expect(rule).not_to be_valid
        expect(rule.errors[:min_days_per_week]).to be_present
      end
    end

    describe 'week_start_day' do
      (0..6).each do |day|
        it "#{day} を許可する" do
          rule = build(:auto_schedule_rule, week_start_day: day)
          expect(rule).to be_valid
        end
      end

      it '7 を拒否する' do
        rule = build(:auto_schedule_rule, week_start_day: 7)
        expect(rule).not_to be_valid
        expect(rule.errors[:week_start_day]).to be_present
      end

      it '-1 を拒否する' do
        rule = build(:auto_schedule_rule, week_start_day: -1)
        expect(rule).not_to be_valid
        expect(rule.errors[:week_start_day]).to be_present
      end
    end

    describe 'confirm_days_before' do
      it '正の値を許可する' do
        rule = build(:auto_schedule_rule, confirm_days_before: 1)
        expect(rule).to be_valid
      end

      it '0 を拒否する' do
        rule = build(:auto_schedule_rule, confirm_days_before: 0)
        expect(rule).not_to be_valid
        expect(rule.errors[:confirm_days_before]).to be_present
      end

      it '負の値を拒否する' do
        rule = build(:auto_schedule_rule, confirm_days_before: -1)
        expect(rule).not_to be_valid
        expect(rule.errors[:confirm_days_before]).to be_present
      end
    end

    describe 'min_not_greater_than_max カスタムバリデーション' do
      it 'min が max 以下の場合は有効' do
        rule = build(:auto_schedule_rule, min_days_per_week: 2, max_days_per_week: 3)
        expect(rule).to be_valid
      end

      it 'min と max が同じ場合は有効' do
        rule = build(:auto_schedule_rule, min_days_per_week: 3, max_days_per_week: 3)
        expect(rule).to be_valid
      end

      it 'min が max を超える場合は無効' do
        rule = build(:auto_schedule_rule, min_days_per_week: 5, max_days_per_week: 3)
        expect(rule).not_to be_valid
        expect(rule.errors[:min_days_per_week]).to be_present
      end

      it 'min が nil の場合はカスタムバリデーションをスキップする' do
        rule = build(:auto_schedule_rule, min_days_per_week: nil, max_days_per_week: 3)
        expect(rule).to be_valid
      end

      it 'max が nil の場合はカスタムバリデーションをスキップする' do
        rule = build(:auto_schedule_rule, min_days_per_week: 2, max_days_per_week: nil)
        expect(rule).to be_valid
      end
    end
  end

  describe 'ファクトリ' do
    it 'デフォルトファクトリが有効なレコードを作成する' do
      expect(build(:auto_schedule_rule)).to be_valid
    end
  end
end
