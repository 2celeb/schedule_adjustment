# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GeoIpService do
  describe '.lookup' do
    context 'nil または空文字の場合' do
      it 'nil を返す' do
        expect(described_class.lookup(nil)).to be_nil
      end

      it '空文字の場合は nil を返す' do
        expect(described_class.lookup('')).to be_nil
      end
    end

    context 'ループバックアドレスの場合' do
      it 'IPv4 ループバック（127.0.0.1）で "loopback" を返す' do
        expect(described_class.lookup('127.0.0.1')).to eq 'loopback'
      end

      it 'IPv4 ループバック範囲（127.0.0.0/8）で "loopback" を返す' do
        expect(described_class.lookup('127.255.255.255')).to eq 'loopback'
      end

      it 'IPv6 ループバック（::1）で "loopback" を返す' do
        expect(described_class.lookup('::1')).to eq 'loopback'
      end
    end

    context 'プライベート IP アドレスの場合' do
      it '10.0.0.0/8 範囲で "private" を返す' do
        expect(described_class.lookup('10.0.0.1')).to eq 'private'
        expect(described_class.lookup('10.255.255.255')).to eq 'private'
      end

      it '172.16.0.0/12 範囲で "private" を返す' do
        expect(described_class.lookup('172.16.0.1')).to eq 'private'
        expect(described_class.lookup('172.31.255.255')).to eq 'private'
      end

      it '192.168.0.0/16 範囲で "private" を返す' do
        expect(described_class.lookup('192.168.0.1')).to eq 'private'
        expect(described_class.lookup('192.168.255.255')).to eq 'private'
      end

      it 'IPv4 リンクローカル（169.254.0.0/16）で "private" を返す' do
        expect(described_class.lookup('169.254.1.1')).to eq 'private'
      end

      it 'IPv6 ユニークローカル（fc00::/7）で "private" を返す' do
        expect(described_class.lookup('fd00::1')).to eq 'private'
      end

      it 'IPv6 リンクローカル（fe80::/10）で "private" を返す' do
        expect(described_class.lookup('fe80::1')).to eq 'private'
      end

      it 'IPv6 リンクローカル + ゾーン ID（fe80::1%eth0）で "private" を返す' do
        expect(described_class.lookup('fe80::1%eth0')).to eq 'private'
      end
    end

    context 'パブリック IP アドレスの場合' do
      it '"unknown" を返す（GeoIP データベース未導入）' do
        expect(described_class.lookup('203.0.113.1')).to eq 'unknown'
      end

      it '別のパブリック IP でも "unknown" を返す' do
        expect(described_class.lookup('8.8.8.8')).to eq 'unknown'
      end

      it 'IPv6 パブリックアドレスで "unknown" を返す' do
        expect(described_class.lookup('2001:db8::1')).to eq 'unknown'
      end
    end

    context '不正な IP アドレスの場合' do
      it '不正な文字列で nil を返す' do
        expect(described_class.lookup('not-an-ip')).to be_nil
      end

      it '範囲外の IP で nil を返す' do
        expect(described_class.lookup('999.999.999.999')).to be_nil
      end
    end
  end
end
