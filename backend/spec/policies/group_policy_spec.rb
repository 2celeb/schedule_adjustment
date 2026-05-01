# frozen_string_literal: true

require "rails_helper"

RSpec.describe GroupPolicy do
  let(:owner) { create(:user) }
  let(:group) { create(:group, owner: owner) }
  let(:other_user) { create(:user) }

  describe "#update?" do
    context "Owner の場合" do
      subject { described_class.new(owner, group) }

      it "true を返す" do
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

  describe "#regenerate_token?" do
    context "Owner の場合" do
      subject { described_class.new(owner, group) }

      it "true を返す" do
        expect(subject.regenerate_token?).to be true
      end
    end

    context "Owner 以外のユーザーの場合" do
      subject { described_class.new(other_user, group) }

      it "false を返す" do
        expect(subject.regenerate_token?).to be false
      end
    end

    context "ユーザーが nil の場合" do
      subject { described_class.new(nil, group) }

      it "false を返す" do
        expect(subject.regenerate_token?).to be false
      end
    end
  end
end
