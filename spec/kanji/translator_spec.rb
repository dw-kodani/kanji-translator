# frozen_string_literal: true

RSpec.describe Kanji::Translator do
  let(:novel_text) do
    "『吾輩は猫である』（わがはいはねこである）は、夏目漱石の長編小説であり、処女小説である。" \
      "1905年（明治38年）1月、『ホトトギス』にて発表されたのだが、好評を博したため、翌1906年（明治39年）" \
      "8月まで連載は継続した。上、1905年10月刊、中、1906年11月刊、下、1907年5月刊。"
  end

  it "has a version number" do
    expect(Kanji::Translator::VERSION).not_to be nil
  end

  describe ".to_hira" do
    it "fetches hiragana reading for the novel text" do
      require "uri"
      encoded = URI.encode_www_form_component(novel_text)
      body = "<table id=\"yomikata\"><tbody><tr><td>わがはいはねこである</td></tr></tbody></table>"
      stub_request(:get, "https://yomikatawa.com/kanji/#{encoded}")
        .with(headers: { "User-Agent" => /kanji-translator/i })
        .to_return(status: 200, body: body, headers: { "Content-Type" => "text/html" })

      expect(Kanji::Translator.to_hira(novel_text)).to eq("わがはいはねこである")
    end

    it "retries on 429 and eventually succeeds" do
      require "uri"
      encoded = URI.encode_www_form_component(novel_text)
      body = "<table id=\"yomikata\"><tbody><tr><td>わがはいはねこである</td></tr></tbody></table>"
      stub = stub_request(:get, "https://yomikatawa.com/kanji/#{encoded}")
             .to_return({ status: 429, headers: { "Retry-After" => "0" } },
                        { status: 200, body: body })

      expect(Kanji::Translator.to_hira(novel_text, retries: 1, backoff: 0.0)).to eq("わがはいはねこである")
      expect(stub).to have_been_requested.twice
    end

    it "raises on timeout" do
      require "uri"
      encoded = URI.encode_www_form_component(novel_text)
      stub_request(:get, "https://yomikatawa.com/kanji/#{encoded}")
        .to_timeout

      expect do
        Kanji::Translator.to_hira(novel_text, timeout: 0.01, retries: 0)
      end.to raise_error(Kanji::Translator::TimeoutError)
    end
  end

  describe ".to_kata" do
    it "converts to katakana from the novel text reading" do
      require "uri"
      encoded = URI.encode_www_form_component(novel_text)
      body = "<table id=\"yomikata\"><tbody><tr><td>わがはいはねこである</td></tr></tbody></table>"
      stub_request(:get, "https://yomikatawa.com/kanji/#{encoded}")
        .to_return(status: 200, body: body)
      expect(Kanji::Translator.to_kata(novel_text)).to eq("ワガハイハネコデアル")
    end
  end

  describe ".to_roma" do
    it "converts to romaji (Hepburn) from the novel text reading" do
      require "uri"
      encoded = URI.encode_www_form_component(novel_text)
      body = "<table id=\"yomikata\"><tbody><tr><td>わがはいはねこである</td></tr></tbody></table>"
      stub_request(:get, "https://yomikatawa.com/kanji/#{encoded}")
        .to_return(status: 200, body: body)
      expect(Kanji::Translator.to_roma(novel_text)).to eq("wagahaihanekodearu")
    end
  end

  describe ".to_slug" do
    # space-based optionと個別語テストは削除。統合テストでカバー。

    it "handles the full novel excerpt end-to-end" do
      # Stub all kanji lookups generically to avoid listing every token
      any_html = "<table id=\"yomikata\"><tbody><tr><td>かな</td></tr></tbody></table>"
      stub_request(:get, %r{https://yomikatawa.com/kanji/.*}).to_return(status: 200, body: any_html)

      slug = Kanji::Translator.to_slug(novel_text)

      expect(slug).to match(/hototogisu/) # Katakana handled locally
      expect(slug).to include("1905")
      expect(slug).to include("1906")
      expect(slug).to include("1907")
      expect(slug).to match(/\A[a-z0-9-]+\z/) # only ascii lower + digits + hyphen
      expect(slug).not_to include("--") # no double separators
    end
  end

  describe "String monkey patch (optional)" do
    it "adds String#to_hira when core_ext is required" do
      require "kanji/translator/core_ext/string"

      require "uri"
      encoded = URI.encode_www_form_component(novel_text)
      body = "<table id=\"yomikata\"><tbody><tr><td>わがはいはねこである</td></tr></tbody></table>"
      stub_request(:get, "https://yomikatawa.com/kanji/#{encoded}")
        .to_return(status: 200, body: body)
      expect(novel_text.to_hira).to eq("わがはいはねこである")
    end
  end
end
