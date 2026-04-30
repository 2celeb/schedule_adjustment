# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionManagement, type: :controller do
  # テスト用の匿名コントローラーを作成
  controller(ApplicationController) do
    def index
      if current_user
        render json: { user_id: current_user.id }
      else
        render json: { user_id: nil }
      end
    end

    def create
      user = User.find(params[:user_id])
      session = create_session(user, request)
      render json: { session_id: session.id }
    end

    def destroy
      destroy_session
      head :no_content
    end

    def protected_action
      authenticate_session!
      return if performed?

      render json: { message: "ok" }
    end
  end

  before do
    routes.draw do
      get "index" => "anonymous#index"
      post "create" => "anonymous#create"
      delete "destroy" => "anonymous#destroy"
      get "protected_action" => "anonymous#protected_action"
    end
  end

  let(:user) { create(:user, :with_discord) }

  describe "#current_user" do
    context "有効なセッション Cookie がある場合" do
      let(:session_record) { create(:session, user: user) }

      before do
        cookies["_session_token"] = session_record.token
      end

      it "ユーザーを返す" do
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(user.id)
      end

      it "セッションの有効期限を自動延長する" do
        original_expires = session_record.expires_at
        travel_to 1.day.from_now do
          get :index
          session_record.reload
          expect(session_record.expires_at).to be > original_expires
        end
      end
    end

    context "セッション Cookie がない場合" do
      it "nil を返す" do
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to be_nil
      end
    end

    context "無効なトークンの Cookie がある場合" do
      before do
        cookies["_session_token"] = "invalid_token_value"
      end

      it "nil を返す" do
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to be_nil
      end
    end

    context "期限切れセッションの Cookie がある場合" do
      let(:expired_session) { create(:session, :expired, user: user) }

      before do
        cookies["_session_token"] = expired_session.token
      end

      it "nil を返す" do
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to be_nil
      end

      it "期限切れセッションレコードを削除する" do
        expect {
          get :index
        }.to change(Session, :count).by(-1)
      end
    end
  end

  describe "#authenticate_session!" do
    context "有効なセッションがある場合" do
      let(:session_record) { create(:session, user: user) }

      before do
        cookies["_session_token"] = session_record.token
      end

      it "リクエストを許可する" do
        get :protected_action
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["message"]).to eq("ok")
      end
    end

    context "セッションがない場合" do
      it "401 を返す" do
        get :protected_action
        expect(response).to have_http_status(:unauthorized)
      end

      it "エラーレスポンスを返す" do
        get :protected_action
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end
  end

  describe "#create_session" do
    it "セッションレコードを作成する" do
      expect {
        post :create, params: { user_id: user.id }
      }.to change(Session, :count).by(1)
    end

    it "セッション Cookie を設定する" do
      post :create, params: { user_id: user.id }
      expect(cookies["_session_token"]).to be_present
    end

    it "セッションに正しい属性を設定する" do
      post :create, params: { user_id: user.id }
      session_record = Session.last
      expect(session_record.user).to eq(user)
      expect(session_record.token).to be_present
      expect(session_record.token.length).to eq(64) # hex(32) = 64文字
      expect(session_record.expires_at).to be_within(1.minute).of(30.days.from_now)
      expect(session_record.user_agent).to be_present
    end
  end

  describe "#destroy_session" do
    let(:session_record) { create(:session, user: user) }

    before do
      cookies["_session_token"] = session_record.token
    end

    it "セッションレコードを削除する" do
      expect {
        delete :destroy
      }.to change(Session, :count).by(-1)
    end

    it "Cookie をクリアする" do
      delete :destroy
      # destroy 後に Cookie が削除されていることを確認
      expect(response.cookies["_session_token"]).to be_nil
    end
  end

  describe "セッション有効期限の自動延長" do
    let(:session_record) { create(:session, user: user, expires_at: 15.days.from_now) }

    before do
      cookies["_session_token"] = session_record.token
    end

    it "アクセス時に有効期限を30日後に延長する" do
      get :index
      session_record.reload
      expect(session_record.expires_at).to be_within(1.minute).of(30.days.from_now)
    end

    it "IP アドレスを更新する" do
      get :index
      session_record.reload
      expect(session_record.ip_address).to be_present
    end
  end
end
