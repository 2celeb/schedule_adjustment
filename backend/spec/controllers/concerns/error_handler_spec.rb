# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorHandler, type: :request do
  # テスト用ルートを動的に定義
  before(:all) do
    # テスト用コントローラーを定義
    test_controller = Class.new(ApplicationController) do
      skip_before_action :set_request_context

      def internal_error
        raise StandardError, "予期しないエラー"
      end

      def parameter_missing
        params.require(:required_param)
      end

      def record_not_found
        raise ActiveRecord::RecordNotFound, "レコードが見つかりません"
      end

      def record_not_unique
        raise ActiveRecord::RecordNotUnique, "一意制約違反"
      end

      def google_oauth_error
        raise GoogleOauthService::TokenExchangeError, "トークン交換に失敗"
      end

      def freebusy_error
        raise FreebusySyncService::FreeBusyApiError, "FreeBusy API エラー"
      end

      def network_timeout
        raise Net::OpenTimeout, "接続タイムアウト"
      end

      def connection_refused
        raise Errno::ECONNREFUSED, "接続拒否"
      end

      def socket_error
        raise SocketError, "DNS 解決失敗"
      end

      def read_timeout
        raise Net::ReadTimeout, "読み取りタイムアウト"
      end

      def success
        render json: { message: "OK" }, status: :ok
      end
    end

    # コントローラーを定数として登録
    Object.const_set(:ErrorHandlerTestController, test_controller)

    # テスト用ルートを追加
    Rails.application.routes.draw do
      get "test/internal_error", to: "error_handler_test#internal_error"
      get "test/parameter_missing", to: "error_handler_test#parameter_missing"
      get "test/record_not_found", to: "error_handler_test#record_not_found"
      get "test/record_not_unique", to: "error_handler_test#record_not_unique"
      get "test/google_oauth_error", to: "error_handler_test#google_oauth_error"
      get "test/freebusy_error", to: "error_handler_test#freebusy_error"
      get "test/network_timeout", to: "error_handler_test#network_timeout"
      get "test/connection_refused", to: "error_handler_test#connection_refused"
      get "test/socket_error", to: "error_handler_test#socket_error"
      get "test/read_timeout", to: "error_handler_test#read_timeout"
      get "test/success", to: "error_handler_test#success"
    end
  end

  after(:all) do
    Rails.application.reload_routes!
    Object.send(:remove_const, :ErrorHandlerTestController) if Object.const_defined?(:ErrorHandlerTestController)
  end

  # 共通のレスポンス形式チェック
  shared_examples "統一エラーレスポンス" do |expected_status, expected_code|
    it "HTTP ステータス #{expected_status} を返す" do
      expect(response).to have_http_status(expected_status)
    end

    it "統一 JSON 形式のエラーレスポンスを返す" do
      body = JSON.parse(response.body)
      expect(body).to have_key("error")
      expect(body["error"]).to have_key("code")
      expect(body["error"]).to have_key("message")
      expect(body["error"]["code"]).to eq(expected_code)
      expect(body["error"]["message"]).to be_a(String)
      expect(body["error"]["message"]).not_to be_empty
    end

    it "Content-Type が application/json である" do
      expect(response.content_type).to include("application/json")
    end
  end

  describe "500 Internal Server Error" do
    before { get "/test/internal_error" }

    include_examples "統一エラーレスポンス", :internal_server_error, "INTERNAL_SERVER_ERROR"

    it "エラーメッセージにスタックトレースを含まない" do
      body = JSON.parse(response.body)
      expect(body["error"]["message"]).not_to include("StandardError")
      expect(body["error"]["message"]).not_to include("spec/")
    end
  end

  describe "400 Parameter Missing" do
    before { get "/test/parameter_missing" }

    include_examples "統一エラーレスポンス", :bad_request, "PARAMETER_MISSING"

    it "details にフィールド情報を含む" do
      body = JSON.parse(response.body)
      expect(body["error"]).to have_key("details")
      expect(body["error"]["details"]).to be_an(Array)
      expect(body["error"]["details"].first).to have_key("field")
    end
  end

  describe "404 Record Not Found" do
    before { get "/test/record_not_found" }

    include_examples "統一エラーレスポンス", :not_found, "NOT_FOUND"
  end

  describe "409 Record Not Unique" do
    before { get "/test/record_not_unique" }

    include_examples "統一エラーレスポンス", :conflict, "CONFLICT"
  end

  describe "502 Google OAuth Error" do
    before { get "/test/google_oauth_error" }

    include_examples "統一エラーレスポンス", :bad_gateway, "EXTERNAL_SERVICE_ERROR"
  end

  describe "502 FreeBusy API Error" do
    before { get "/test/freebusy_error" }

    include_examples "統一エラーレスポンス", :bad_gateway, "EXTERNAL_SERVICE_ERROR"
  end

  describe "502 Network Timeout (OpenTimeout)" do
    before { get "/test/network_timeout" }

    include_examples "統一エラーレスポンス", :bad_gateway, "EXTERNAL_SERVICE_TIMEOUT"
  end

  describe "502 Network Timeout (ReadTimeout)" do
    before { get "/test/read_timeout" }

    include_examples "統一エラーレスポンス", :bad_gateway, "EXTERNAL_SERVICE_TIMEOUT"
  end

  describe "502 Connection Refused" do
    before { get "/test/connection_refused" }

    include_examples "統一エラーレスポンス", :bad_gateway, "EXTERNAL_SERVICE_UNAVAILABLE"
  end

  describe "502 Socket Error" do
    before { get "/test/socket_error" }

    include_examples "統一エラーレスポンス", :bad_gateway, "EXTERNAL_SERVICE_UNAVAILABLE"
  end

  describe "正常レスポンスは影響を受けない" do
    before { get "/test/success" }

    it "200 OK を返す" do
      expect(response).to have_http_status(:ok)
    end

    it "正常な JSON レスポンスを返す" do
      body = JSON.parse(response.body)
      expect(body["message"]).to eq("OK")
    end
  end
end
