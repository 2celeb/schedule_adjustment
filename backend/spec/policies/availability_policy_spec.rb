# frozen_string_literal: true

require "rails_helper"

RSpec.describe AvailabilityPolicy do
  let(:owner) { create(:user) }
  let(:group) { create(:group, owner: owner) }
  let(:regular_user) { create(:user) }
  let(:auth_locked_user) { create(:user, :with_google) }

  describe "#update?" do
    context "通常ユーザーが未来の日付を変更する場合" do
      subject { described_class.new(regular_user, group) }

      it "true を返す" do
        expect(subject.update?(date: Date.current + 1)).to be true
      end
    end

    context "通常ユーザーが今日の日付を変更する場合" do
      subject { described_class.new(regular_user, group) }

      it "true を返す" do
        expect(subject.update?(date: Date.current)).to be true
      end
    end

    context "通常ユーザーが過去の日付を変更する場合" do
      subject { described_class.new(regular_user, group) }

      it "false を返す（要件 3.7: 過去日付は一般メンバーに対してロック）" do
        expect(subject.update?(date: Date.current - 1)).to be false
      end
    end

    context "Owner が過去の日付を変更する場合" do
      subject { described_class.new(owner, group) }

      it "true を返す（要件 3.8: Owner は過去日付の変更を許可）" do
        expect(subject.update?(date: Date.current - 1)).to be true
      end
    end

    context "auth_locked ユーザーが Cookie 認証なしで変更する場合" do
      subject { described_class.new(auth_locked_user, group) }

      it "false を返す（要件 1.5: auth_locked ユーザーは Cookie 必須）" do
        expect(subject.update?(date: Date.current, authenticated_via_cookie: false)).to be false
      end
    end

    context "auth_locked ユーザーが Cookie 認証ありで未来の日付を変更する場合" do
      subject { described_class.new(auth_locked_user, group) }

      it "true を返す" do
        expect(subject.update?(date: Date.current + 1, authenticated_via_cookie: true)).to be true
      end
    end

    context "auth_locked の Owner が Cookie 認証ありで過去の日付を変更する場合" do
      let(:auth_locked_owner) { create(:user, :with_google) }
      let(:owned_group) { create(:group, owner: auth_locked_owner) }
      subject { described_class.new(auth_locked_owner, owned_group) }

      it "true を返す" do
        expect(subject.update?(date: Date.current - 1, authenticated_via_cookie: true)).to be true
      end
    end

    context "auth_locked の Owner が Cookie 認証なしで変更する場合" do
      let(:auth_locked_owner) { create(:user, :with_google) }
      let(:owned_group) { create(:group, owner: auth_locked_owner) }
      subject { described_class.new(auth_locked_owner, owned_group) }

      it "false を返す（auth_locked は Cookie 必須が優先）" do
        expect(subject.update?(date: Date.current + 1, authenticated_via_cookie: false)).to be false
      end
    end

    context "ユーザーが nil の場合" do
      subject { described_class.new(nil, group) }

      it "false を返す" do
        expect(subject.update?(date: Date.current)).to be false
      end
    end
  end
end
