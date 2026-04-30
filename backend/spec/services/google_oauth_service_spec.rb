# frozen_string_literal: true

require 'rails_helper'
require 'net/http'

RSpec.describe GoogleOauthService do
  let(:client_id) { "test_client_id" }
  let(:client_secret) { "test_client_secret" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_ID").and_return(client_id)
    allow(ENV).to receive(:fetch).with("GOOGLE_CLIENT_SECRET").and_return(client_secret)
  end

  subject(:service) { described_class.new }

  describe "#authorization_url" do
    let(:redirect_uri) { "http://localhost:3000/oauth/google/callback" }

    it "Google 認証URLを返す" do
      url = service.authorization_url(redirect_uri: redirect_uri)
      expect(url).to start_with("https://accounts.google.com/o/oauth2/v2/auth")
    end

    it "必要なパラメータが含まれる" do
      url = service.authorization_url(redirect_uri: redirect_uri)
      uri = URI.parse(url)
      query = Rack::Utils.parse_query(uri.query)

      expect(query["client_id"]).to eq(client_id)
      expect(query["redirect_uri"]).to eq(redirect_uri)
      expect(query["response_type"]).to eq("code")
      expect(query["access_type"]).to eq("offline")
      expect(query["prompt"]).to eq("consent")
    end

    it "デフォルトスコープは freebusy" do
      url = service.authorization_url(redirect_uri: redirect_uri)
      uri = URI.parse(url)
      query = Rack::Utils.parse_query(uri.query)

      expect(query["scope"]).to include("calendar.freebusy.readonly")
    end

    it "scope_pattern=freebusy_events で予定枠+書き込みスコープが設定される" do
      url = service.authorization_url(redirect_uri: redirect_uri, scope_pattern: "freebusy_events")
      uri = URI.parse(url)
      query = Rack::Utils.parse_query(uri.query)

      expect(query["scope"]).to include("calendar.freebusy.readonly")
      expect(query["scope"]).to include("calendar.events")
    end

    it "scope_pattern=calendar でフルカレンダースコープが設定される" do
      url = service.authorization_url(redirect_uri: redirect_uri, scope_pattern: "calendar")
      uri = URI.parse(url)
      query = Rack::Utils.parse_query(uri.query)

      expect(query["scope"]).to include("auth/calendar")
    end

    it "state パラメータが含まれる" do
      url = service.authorization_url(redirect_uri: redirect_uri, state: "test_state")
      uri = URI.parse(url)
      query = Rack::Utils.parse_query(uri.query)

      expect(query["state"]).to eq("test_state")
    end

    it "state が nil の場合はパラメータに含まれない" do
      url = service.authorization_url(redirect_uri: redirect_uri)
      uri = URI.parse(url)
      query = Rack::Utils.parse_query(uri.query)

      expect(query).not_to have_key("state")
    end

    it "openid と email スコープが常に含まれる" do
      url = service.authorization_url(redirect_uri: redirect_uri)
      uri = URI.parse(url)
      query = Rack::Utils.parse_query(uri.query)

      expect(query["scope"]).to include("openid")
      expect(query["scope"]).to include("email")
    end

    it "不明な scope_pattern の場合はデフォルト（freebusy）にフォールバックする" do
      url = service.authorization_url(redirect_uri: redirect_uri, scope_pattern: "unknown")
      uri = URI.parse(url)
      query = Rack::Utils.parse_query(uri.query)

      expect(query["scope"]).to include("calendar.freebusy.readonly")
    end
  end

  describe "#exchange_code" do
    let(:redirect_uri) { "http://localhost:3000/oauth/google/callback" }
    let(:code) { "test_auth_code" }

    context "トークン交換が成功する場合" do
      let(:response_body) do
        {
          "access_token" => "access_token_123",
          "refresh_token" => "refresh_token_456",
          "expires_in" => 3600,
          "token_type" => "Bearer"
        }.to_json
      end

      before do
        response = Net::HTTPOK.new("1.1", "200", "OK")
        allow(response).to receive(:body).and_return(response_body)
        allow(Net::HTTP).to receive(:post_form).and_return(response)
      end

      it "トークン情報を返す" do
        result = service.exchange_code(code: code, redirect_uri: redirect_uri)

        expect(result["access_token"]).to eq("access_token_123")
        expect(result["refresh_token"]).to eq("refresh_token_456")
        expect(result["expires_in"]).to eq(3600)
      end
    end

    context "トークン交換が失敗する場合" do
      let(:error_body) do
        { "error" => "invalid_grant", "error_description" => "Code expired" }.to_json
      end

      before do
        response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
        allow(response).to receive(:body).and_return(error_body)
        allow(Net::HTTP).to receive(:post_form).and_return(response)
      end

      it "TokenExchangeError を発生させる" do
        expect {
          service.exchange_code(code: code, redirect_uri: redirect_uri)
        }.to raise_error(GoogleOauthService::TokenExchangeError, /Code expired/)
      end
    end
  end

  describe "#fetch_user_info" do
    let(:access_token) { "test_access_token" }

    context "ユーザー情報取得が成功する場合" do
      let(:response_body) do
        { "sub" => "google_sub_123", "email" => "test@example.com" }.to_json
      end

      before do
        response = Net::HTTPOK.new("1.1", "200", "OK")
        allow(response).to receive(:body).and_return(response_body)

        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:request).and_return(response)
      end

      it "ユーザー情報を返す" do
        result = service.fetch_user_info(access_token: access_token)

        expect(result["sub"]).to eq("google_sub_123")
        expect(result["email"]).to eq("test@example.com")
      end
    end

    context "ユーザー情報取得が失敗する場合" do
      let(:error_body) do
        { "error" => "invalid_token" }.to_json
      end

      before do
        response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
        allow(response).to receive(:body).and_return(error_body)

        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:request).and_return(response)
      end

      it "UserInfoError を発生させる" do
        expect {
          service.fetch_user_info(access_token: access_token)
        }.to raise_error(GoogleOauthService::UserInfoError, /invalid_token/)
      end
    end
  end
end
