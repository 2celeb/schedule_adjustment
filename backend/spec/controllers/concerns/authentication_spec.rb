# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authentication, type: :controller do
  # テスト用の匿名コントローラーを作成
  controller(ApplicationController) do
    def index
      if current_user_or_loose
        render json: { user_id: current_user_or_loose.id }
      else
        render json: { user_id: nil }
      end
    end

    def current_user_action
      if current_user
        render json: { user_id: current_user.id }
      else
        render json: { user_id: nil }
      end
    end

    def protected_action
      authenticate_user!
      return if performed?

      render json: { message: "ok", user_id: current_user_or_loose.id }
    end

    def strict_action
      authenticate_strict!
      return if performed?

      render json: { message: "ok", user_id: current_user_or_loose.id }
    end

    def session_only_action
      authenticate_session!
      return if performed?

      render json: { message: "ok", user_id: current_user.id }
    end
  end

  before do
    routes.draw do
      get "index" => "anonymous#index"
      get "current_user_action" => "anonymous#current_user_action"
      get "protected_action" => "anonymous#protected_action"
      get "strict_action" => "anonymous#strict_action"
      get "session_only_action" => "anonymous#session_only_action"
    end
  end

  let(:user) { create(:user, :with_discord, auth_locked: false) }
  let(:locked_user) { create(:user, :with_google) } # auth_locked: true

  describe "#current_user_or_loose（2層認証）" do
    context "Cookie セッションで認証されたユーザー（auth_locked=false）" do
      let(:session_record) { create(:session, user: user) }

      before { cookies["_session_token"] = session_record.token }

      it "ユーザーを返す" do
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(user.id)
      end
    end

    context "Cookie セッションで認証されたユーザー（auth_locked=true）" do
      let(:session_record) { create(:session, user: locked_user) }

      before { cookies["_session_token"] = session_record.token }

      it "ユーザーを返す（Cookie 認証済みなので auth_locked チェック不要）" do
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(locked_user.id)
      end
    end

    context "X-User-Id ヘッダーで識別されたユーザー（auth_locked=false）" do
      it "ユーザーを返す" do
        request.headers["X-User-Id"] = user.id.to_s
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(user.id)
      end
    end

    context "X-User-Id ヘッダーで識別されたユーザー（auth_locked=true）" do
      it "nil を返す（Cookie 必須のため）" do
        request.headers["X-User-Id"] = locked_user.id.to_s
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to be_nil
      end
    end

    context "Cookie が X-User-Id ヘッダーより優先される" do
      let(:other_user) { create(:user, :with_discord, auth_locked: false) }
      let(:session_record) { create(:session, user: user) }

      before { cookies["_session_token"] = session_record.token }

      it "Cookie のユーザーを返す（X-User-Id は無視）" do
        request.headers["X-User-Id"] = other_user.id.to_s
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(user.id)
      end
    end

    context "認証情報がない場合" do
      it "nil を返す" do
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to be_nil
      end
    end

    context "存在しないユーザー ID が X-User-Id ヘッダーに指定された場合" do
      it "nil を返す" do
        request.headers["X-User-Id"] = "999999"
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to be_nil
      end
    end

    context "X-User-Id ヘッダーが空文字の場合" do
      it "nil を返す" do
        request.headers["X-User-Id"] = ""
        get :index
        body = JSON.parse(response.body)
        expect(body["user_id"]).to be_nil
      end
    end
  end

  describe "#current_user（current_user_or_loose のエイリアス）" do
    context "Cookie セッションで認証されたユーザー" do
      let(:session_record) { create(:session, user: user) }

      before { cookies["_session_token"] = session_record.token }

      it "current_user_or_loose と同じユーザーを返す" do
        get :current_user_action
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(user.id)
      end
    end

    context "X-User-Id ヘッダーで識別されたユーザー（auth_locked=false）" do
      it "current_user_or_loose と同じユーザーを返す" do
        request.headers["X-User-Id"] = user.id.to_s
        get :current_user_action
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(user.id)
      end
    end
  end

  describe "#authenticate_user!" do
    context "Cookie セッションで認証されている場合" do
      let(:session_record) { create(:session, user: user) }

      before { cookies["_session_token"] = session_record.token }

      it "リクエストを許可する" do
        get :protected_action
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(user.id)
      end
    end

    context "Cookie セッションで認証された auth_locked=true ユーザー" do
      let(:session_record) { create(:session, user: locked_user) }

      before { cookies["_session_token"] = session_record.token }

      it "リクエストを許可する（Cookie 認証済みなので auth_locked チェック不要）" do
        get :protected_action
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(locked_user.id)
      end
    end

    context "X-User-Id ヘッダーで識別されている場合（auth_locked=false）" do
      it "リクエストを許可する" do
        request.headers["X-User-Id"] = user.id.to_s
        get :protected_action
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(user.id)
      end
    end

    context "認証情報がない場合" do
      it "401 UNAUTHORIZED を返す" do
        get :protected_action
        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("UNAUTHORIZED")
        expect(body["error"]["message"]).to eq("ユーザーの識別ができません。メンバーを選択するか、ログインしてください。")
      end
    end

    context "X-User-Id ヘッダーで auth_locked=true のユーザーを指定した場合" do
      it "401 AUTH_LOCKED を返す" do
        request.headers["X-User-Id"] = locked_user.id.to_s
        get :protected_action
        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("AUTH_LOCKED")
        expect(body["error"]["message"]).to eq("このユーザーはGoogle連携済みのため、ログインが必要です。")
      end
    end

    context "存在しないユーザー ID が X-User-Id ヘッダーに指定された場合" do
      it "UNAUTHORIZED エラーを返す" do
        request.headers["X-User-Id"] = "999999"
        get :protected_action
        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("UNAUTHORIZED")
      end
    end
  end

  describe "#authenticate_strict!" do
    context "Cookie セッションで認証されたユーザー（auth_locked=false）" do
      let(:session_record) { create(:session, user: user) }

      before { cookies["_session_token"] = session_record.token }

      it "リクエストを許可する" do
        get :strict_action
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(user.id)
      end
    end

    context "Cookie セッションで認証された auth_locked=true ユーザー" do
      let(:session_record) { create(:session, user: locked_user) }

      before { cookies["_session_token"] = session_record.token }

      it "リクエストを許可する（Cookie 認証済み）" do
        get :strict_action
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(locked_user.id)
      end
    end

    context "X-User-Id ヘッダーで識別されたユーザー（auth_locked=false）" do
      it "リクエストを許可する（auth_locked=false なので X-User-Id で OK）" do
        request.headers["X-User-Id"] = user.id.to_s
        get :strict_action
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(user.id)
      end
    end

    context "X-User-Id ヘッダーで auth_locked=true のユーザーを指定した場合" do
      it "401 AUTH_LOCKED を返す（Cookie 必須）" do
        request.headers["X-User-Id"] = locked_user.id.to_s
        get :strict_action
        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("AUTH_LOCKED")
        expect(body["error"]["message"]).to eq("このユーザーはGoogle連携済みのため、ログインが必要です。")
      end
    end

    context "認証情報がない場合" do
      it "401 UNAUTHORIZED を返す" do
        get :strict_action
        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("UNAUTHORIZED")
        expect(body["error"]["message"]).to eq("ユーザーの識別ができません。メンバーを選択するか、ログインしてください。")
      end
    end
  end

  describe "#authenticate_session!（SessionManagement から継承）" do
    context "Cookie セッションで認証されている場合" do
      let(:session_record) { create(:session, user: user) }

      before { cookies["_session_token"] = session_record.token }

      it "リクエストを許可する" do
        get :session_only_action
        expect(response).to have_http_status(:ok)
      end
    end

    context "X-User-Id ヘッダーのみの場合" do
      it "401 を返す（Cookie 必須）" do
        request.headers["X-User-Id"] = user.id.to_s
        get :session_only_action
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "#authenticated_via_cookie?" do
    context "有効な Cookie セッションがある場合" do
      let(:session_record) { create(:session, user: user) }

      before { cookies["_session_token"] = session_record.token }

      it "Cookie 認証済みと判定される（auth_locked ユーザーでも許可）" do
        # Cookie があるので auth_locked_header_only? は false
        # Cookie のユーザーが返される
        request.headers["X-User-Id"] = locked_user.id.to_s
        get :protected_action
        expect(response).to have_http_status(:ok)
      end
    end

    context "期限切れの Cookie セッションがある場合" do
      let(:expired_session) { create(:session, :expired, user: user) }

      before { cookies["_session_token"] = expired_session.token }

      it "Cookie 認証済みと判定されない" do
        get :protected_action
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "Cookie 期限切れ + X-User-Id ヘッダーあり（auth_locked=false）" do
      let(:expired_session) { create(:session, :expired, user: locked_user) }

      before { cookies["_session_token"] = expired_session.token }

      it "X-User-Id にフォールバックしてユーザーを返す" do
        request.headers["X-User-Id"] = user.id.to_s
        get :protected_action
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["user_id"]).to eq(user.id)
      end
    end

    context "Cookie 期限切れ + X-User-Id ヘッダーあり（auth_locked=true）" do
      let(:expired_session) { create(:session, :expired, user: user) }

      before { cookies["_session_token"] = expired_session.token }

      it "auth_locked ユーザーは X-User-Id フォールバックでも拒否される" do
        request.headers["X-User-Id"] = locked_user.id.to_s
        get :protected_action
        expect(response).to have_http_status(:unauthorized)
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("AUTH_LOCKED")
      end
    end
  end

  describe "エラーレスポンス形式" do
    context "authenticate_user! の UNAUTHORIZED レスポンス" do
      it "統一エラー形式（error.code + error.message）で返す" do
        get :protected_action
        body = JSON.parse(response.body)
        expect(body).to have_key("error")
        expect(body["error"]).to have_key("code")
        expect(body["error"]).to have_key("message")
        expect(body["error"]["code"]).to eq("UNAUTHORIZED")
        expect(body["error"]["message"]).to eq("ユーザーの識別ができません。メンバーを選択するか、ログインしてください。")
      end
    end

    context "authenticate_user! の AUTH_LOCKED レスポンス" do
      it "統一エラー形式（error.code + error.message）で返す" do
        request.headers["X-User-Id"] = locked_user.id.to_s
        get :protected_action
        body = JSON.parse(response.body)
        expect(body).to have_key("error")
        expect(body["error"]).to have_key("code")
        expect(body["error"]).to have_key("message")
        expect(body["error"]["code"]).to eq("AUTH_LOCKED")
        expect(body["error"]["message"]).to eq("このユーザーはGoogle連携済みのため、ログインが必要です。")
      end
    end
  end
end
