# frozen_string_literal: true

require 'rails_helper'
require 'net/http'

RSpec.describe DiscordOauthService do
  let(:client_id) { "test_discord_client_id" }
  let(:client_secret) { "test_discord_client_secret" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DISCORD_CLIENT_ID").and_return(client_id)
    allow(ENV).to receive(:fetch).with("DISCORD_CLIENT_SECRET").and_return(client_secret)
  end

  subject(:service) { described_class.new }

  describe "#authorization_url" do
    let(:redirect_uri) { "http://localhost:3000/oauth/discord/callback" }

    it "Discord 認証URLを返す" do
      url = service.authorization_url(redirect_uri: redirect_uri)
      expect(url).to start_with("https://discord.com/oauth2/authorize")
    end

    it "必要なパラメータが含まれる" do
      url = service.authorization_url(redirect_uri: redirect_uri)
      uri = URI.parse(url)
      query = Rack::Utils.parse_query(uri.query)
      expect(query["client_id"]).to eq(client_id)
      expect(query["redirect_uri"]).to eq(redirect_uri)
      expect(query["response_type"]).to eq("code")
      expect(query["scope"]).to eq("identify")
    end

    it "state パラメータが指定された場合に含まれる" do
      url = service.authorization_url(redirect_uri: redirect_uri, state: "test_state")
      uri = URI.parse(url)
      query = Rack::Utils.parse_query(uri.query)
      expect(query["state"]).to eq("test_state")
    end

    it "state パラメータが未指定の場合は含まれない" do
      url = service.authorization_url(redirect_uri: redirect_uri)
      uri = URI.parse(url)
      query = Rack::Utils.parse_query(uri.query)
      expect(query).not_to have_key("state")
    end
  end

  describe "#exchange_code" do
    let(:redirect_uri) { "http://localhost:3000/oauth/discord/callback" }
    let(:code) { "test_auth_code" }

    context "トークン交換が成功する場合" do
      let(:response_body) do
        { "access_token" => "mock_token", "token_type" => "Bearer", "scope" => "identify" }.to_json
      end

      before do
        response = Net::HTTPOK.new("1.1", "200", "OK")
        allow(response).to receive(:body).and_return(response_body)
        allow(Net::HTTP).to receive(:post_form).and_return(response)
      end

      it "トークン情報を返す" do
        result = service.exchange_code(code: code, redirect_uri: redirect_uri)
        expect(result["access_token"]).to eq("mock_token")
        expect(result["token_type"]).to eq("Bearer")
      end
    end

    context "トークン交換が失敗する場合" do
      let(:error_body) do
        { "error" => "invalid_grant", "error_description" => "Invalid code" }.to_json
      end

      before do
        response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
        allow(response).to receive(:body).and_return(error_body)
        allow(Net::HTTP).to receive(:post_form).and_return(response)
      end

      it "TokenExchangeError を発生させる" do
        expect {
          service.exchange_code(code: code, redirect_uri: redirect_uri)
        }.to raise_error(DiscordOauthService::TokenExchangeError, /Invalid code/)
      end
    end
  end

  describe "#fetch_user_info" do
    let(:access_token) { "mock_access_token" }

    context "ユーザー情報取得が成功する場合" do
      let(:response_body) do
        { "id" => "123456789", "username" => "testuser", "global_name" => "テストユーザー" }.to_json
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
        expect(result["id"]).to eq("123456789")
        expect(result["username"]).to eq("testuser")
        expect(result["global_name"]).to eq("テストユーザー")
      end
    end

    context "ユーザー情報取得が失敗する場合" do
      let(:error_body) do
        { "message" => "401: Unauthorized" }.to_json
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
        }.to raise_error(DiscordOauthService::UserInfoError, /Unauthorized/)
      end
    end
  end
end
