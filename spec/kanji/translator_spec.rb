# frozen_string_literal: true

RSpec.describe Kanji::Translator do
  let(:html_fixture_path) { File.expand_path("../fixtures/yomikata_gakkou_annai.html", __dir__) }
  let(:html_body) { File.read(html_fixture_path) }

  it "has a version number" do
    expect(Kanji::Translator::VERSION).not_to be nil
  end

  describe ".to_hira" do
    it "fetches hiragana reading for 学校案内" do
      stub_request(:get, "https://yomikatawa.com/kanji/%E5%AD%A6%E6%A0%A1%E6%A1%88%E5%86%85")
        .with(headers: { "User-Agent" => /kanji-translator/i })
        .to_return(status: 200, body: html_body, headers: { "Content-Type" => "text/html" })

      expect(Kanji::Translator.to_hira("学校案内")).to eq("がっこうあんない")
    end

    it "retries on 429 and eventually succeeds" do
      stub = stub_request(:get, "https://yomikatawa.com/kanji/%E5%AD%A6%E6%A0%A1%E6%A1%88%E5%86%85")
             .to_return({ status: 429, headers: { "Retry-After" => "0" } },
                        { status: 200, body: html_body })

      expect(Kanji::Translator.to_hira("学校案内", retries: 1, backoff: 0.0)).to eq("がっこうあんない")
      expect(stub).to have_been_requested.twice
    end

    it "raises on timeout" do
      stub_request(:get, "https://yomikatawa.com/kanji/%E5%AD%A6%E6%A0%A1%E6%A1%88%E5%86%85")
        .to_timeout

      expect do
        Kanji::Translator.to_hira("学校案内", timeout: 0.01, retries: 0)
      end.to raise_error(Kanji::Translator::TimeoutError)
    end
  end

  describe ".to_kata" do
    it "converts to katakana" do
      stub_request(:get, "https://yomikatawa.com/kanji/%E5%AD%A6%E6%A0%A1%E6%A1%88%E5%86%85")
        .to_return(status: 200, body: html_body)
      expect(Kanji::Translator.to_kata("学校案内")).to eq("ガッコウアンナイ")
    end
  end

  describe ".to_roma" do
    it "converts to romaji (Hepburn)" do
      stub_request(:get, "https://yomikatawa.com/kanji/%E5%AD%A6%E6%A0%A1%E6%A1%88%E5%86%85")
        .to_return(status: 200, body: html_body)
      expect(Kanji::Translator.to_roma("学校案内")).to eq("gakkouannai")
    end
  end

  describe ".to_slug" do
    it "produces a URL-friendly slug (no segmentation)" do
      # When no segmentation is used, it should not insert hyphens for compound nouns.
      stub_request(:get, "https://yomikatawa.com/kanji/%E5%AD%A6%E6%A0%A1%E6%A1%88%E5%86%85")
        .to_return(status: 200, body: html_body)
      expect(Kanji::Translator.to_slug("学校案内", segmenter: nil)).to eq("gakkouannai")
    end

    it "segments compound nouns by default (tiny)" do
      # default segmenter is :tiny -> splits into ["学校", "案内"] and converts each
      gakkou_html = <<~HTML
        <table id="yomikata"><tbody><tr><td>がっこう</td></tr></tbody></table>
      HTML
      annai_html = <<~HTML
        <table id="yomikata"><tbody><tr><td>あんない</td></tr></tbody></table>
      HTML

      stub_request(:get, "https://yomikatawa.com/kanji/%E5%AD%A6%E6%A0%A1").to_return(status: 200, body: gakkou_html)
      stub_request(:get, "https://yomikatawa.com/kanji/%E6%A1%88%E5%86%85").to_return(status: 200, body: annai_html)

      expect(Kanji::Translator.to_slug("学校案内")).to eq("gakkou-annai")
    end

    it "supports space-based segmentation when segmenter: :space" do
      gakkou_html = <<~HTML
        <table id="yomikata"><tbody><tr><td>がっこう</td></tr></tbody></table>
      HTML
      annai_html = <<~HTML
        <table id="yomikata"><tbody><tr><td>あんない</td></tr></tbody></table>
      HTML

      stub_request(:get, "https://yomikatawa.com/kanji/%E5%AD%A6%E6%A0%A1").to_return(status: 200, body: gakkou_html)
      stub_request(:get, "https://yomikatawa.com/kanji/%E6%A1%88%E5%86%85").to_return(status: 200, body: annai_html)

      expect(Kanji::Translator.to_slug("学校 案内", segmenter: :space)).to eq("gakkou-annai")
    end

    it "allows no segmentation when segmenter: nil" do
      gakkou_annai_html = <<~HTML
        <table id="yomikata"><tbody><tr><td>がっこうあんない</td></tr></tbody></table>
      HTML

      stub_request(:get, "https://yomikatawa.com/kanji/%E5%AD%A6%E6%A0%A1%E6%A1%88%E5%86%85")
        .to_return(status: 200, body: gakkou_annai_html)

      expect(Kanji::Translator.to_slug("学校案内", segmenter: nil)).to eq("gakkouannai")
    end
  end

  describe "String monkey patch (optional)" do
    it "adds String#to_hira when core_ext is required" do
      require "kanji/translator/core_ext/string"

      stub_request(:get, "https://yomikatawa.com/kanji/%E5%AD%A6%E6%A0%A1%E6%A1%88%E5%86%85")
        .to_return(status: 200, body: html_body)
      expect("学校案内".to_hira).to eq("がっこうあんない")
    end
  end
end
