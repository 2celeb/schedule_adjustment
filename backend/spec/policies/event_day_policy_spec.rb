# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventDayPolicy do
  let(:owner) { create(:user) }
  let(:group) { create(:group, owner: owner) }
  let(:other_user) { create(:user) }

  describe "#create?" do
    context "Owner の場合" do
      subject { described_class.new(owner, group) }

      it "true を返す（要件 5.7: Owner のみ活動日を追加可能）" do
        expect(subject.create?).to be true
      end
    end

    context "Owner 以外のユーザーの場合" do
      subject { described_class.new(other_user, group) }

      it "false を返す" do
        expect(subject.create?).to be false
      end
    end

    context "ユーザーが nil の場合" do
      subject { described_class.new(nil, group) }

      it "false を返す" do
        expect(subject.create?).to be false
      end
    end
  end

  describe "#update?" do
    context "Owner の場合" do
      subject { described_class.new(owner, group) }

      it "true を返す（要件 5.8: Owner のみ活動日を変更可能）" do
        expect(subject.update?).to be true
      end
    end

    context "Owner 以外のユーザーの場合" do
      subject { described_class.new(other_user, group) }

      it "false を返す" do
        expect(subject.update?).to be false
      end
    end

    context "ユーザーが nil の場合" do
      subject { described_class.new(nil, group) }

      it "false を返す" do
        expect(subject.update?).to be false
      end
    end
  end

  describe "#destroy?" do
    context "Owner の場合" do
      subject { described_class.new(owner, group) }

      it "true を返す（要件 5.8: Owner のみ活動日を削除可能）" do
        expect(subject.destroy?).to be true
      end
    end

    context "Owner 以外のユーザーの場合" do
      subject { described_class.new(other_user, group) }

      it "false を返す" do
        expect(subject.destroy?).to be false
      end
    end

    context "ユーザーが nil の場合" do
      subject { described_class.new(nil, group) }

      it "false を返す" do
        expect(subject.destroy?).to be false
      end
    end
  end
end
