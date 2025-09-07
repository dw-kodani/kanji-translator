# frozen_string_literal: true

RSpec.describe Kanji::Translator do
  let(:html_fixture_path) { File.expand_path("../fixtures/yomikata_kanji.html", __dir__) }
  let(:html_body) { File.read(html_fixture_path) }

  it "has a version number" do
    expect(Kanji::Translator::VERSION).not_to be nil
  end

  describe ".to_hira" do
    it "fetches hiragana reading for 漢字" do
      stub_request(:get, "https://yomikatawa.com/kanji/%E6%BC%A2%E5%AD%97")
        .with(headers: { "User-Agent" => /kanji-translator/i })
        .to_return(status: 200, body: html_body, headers: { "Content-Type" => "text/html" })

      expect(Kanji::Translator.to_hira("漢字")).to eq("かんじ")
    end

    it "retries on 429 and eventually succeeds" do
      stub = stub_request(:get, "https://yomikatawa.com/kanji/%E6%BC%A2%E5%AD%97")
             .to_return({ status: 429, headers: { "Retry-After" => "0" } },
                        { status: 200, body: html_body })

      expect(Kanji::Translator.to_hira("漢字", retries: 1, backoff: 0.0)).to eq("かんじ")
      expect(stub).to have_been_requested.twice
    end

    it "raises on timeout" do
      stub_request(:get, "https://yomikatawa.com/kanji/%E6%BC%A2%E5%AD%97")
        .to_timeout

      expect do
        Kanji::Translator.to_hira("漢字", timeout: 0.01, retries: 0)
      end.to raise_error(Kanji::Translator::TimeoutError)
    end
  end

  describe ".to_kata" do
    it "converts to katakana" do
      stub_request(:get, "https://yomikatawa.com/kanji/%E6%BC%A2%E5%AD%97")
        .to_return(status: 200, body: html_body)
      expect(Kanji::Translator.to_kata("漢字")).to eq("カンジ")
    end
  end

  describe ".to_roma" do
    it "converts to romaji (Hepburn)" do
      stub_request(:get, "https://yomikatawa.com/kanji/%E6%BC%A2%E5%AD%97")
        .to_return(status: 200, body: html_body)
      expect(Kanji::Translator.to_roma("漢字")).to eq("kanji")
    end
  end

  describe ".to_slug" do
    it "produces a URL-friendly slug" do
      stub_request(:get, "https://yomikatawa.com/kanji/%E6%BC%A2%E5%AD%97")
        .to_return(status: 200, body: html_body)
      expect(Kanji::Translator.to_slug("漢字")).to eq("kanji")
    end
  end

  describe "String monkey patch (optional)" do
    it "adds String#to_hira when core_ext is required" do
      require "kanji/translator/core_ext/string"

      stub_request(:get, "https://yomikatawa.com/kanji/%E6%BC%A2%E5%AD%97")
        .to_return(status: 200, body: html_body)
      expect("漢字".to_hira).to eq("かんじ")
    end
  end
end
