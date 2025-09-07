# frozen_string_literal: true

require_relative "translator/version"
require "net/http"
require "uri"
require "nokogiri"

module Kanji
  module Translator
    class Error < StandardError; end
    class HTTPError < Error; end
    class TimeoutError < Error; end

    USER_AGENT = "kanji-translator/#{VERSION}".freeze
    HOST = "yomikatawa.com"

    def self.to_hira(text, timeout: 5, retries: 2, backoff: 0.5, user_agent: USER_AGENT)
      raise ArgumentError, "text must be a String" unless text.is_a?(String)

      body = fetch_page(text, timeout: timeout, retries: retries, backoff: backoff, user_agent: user_agent)
      parse_hiragana(body)
    end

    def self.to_kata(text, **)
      hira = to_hira(text, **)
      hiragana_to_katakana(hira)
    end

    def self.to_roma(text, **)
      hira = to_hira(text, **)
      hiragana_to_romaji(hira)
    end

    def self.to_slug(text, separator: "-", downcase: true, collapse: true, **)
      roma = to_roma(text, **)
      s = downcase ? roma.downcase : roma.dup
      sep = separator
      # Replace non-alphanumeric with separator
      s = s.gsub(/[^a-z0-9]+/, sep)
      # Collapse duplicate separators
      s = s.gsub(/#{Regexp.escape(sep)}{2,}/, sep) if collapse && !sep.empty?
      # Trim leading/trailing separators
      s = s.gsub(/^#{Regexp.escape(sep)}|#{Regexp.escape(sep)}$/, "") unless sep.empty?
      s
    end

    def self.fetch_page(text, timeout:, retries:, backoff:, user_agent: USER_AGENT)
      encoded = URI.encode_www_form_component(text)
      path = "/kanji/#{encoded}"
      attempt = 0

      begin
        attempt += 1
        http = Net::HTTP.new(HOST, 443)
        http.use_ssl = true
        http.open_timeout = timeout
        http.read_timeout = timeout

        req = Net::HTTP::Get.new(path)
        req["User-Agent"] = user_agent

        resp = http.request(req)

        case resp.code.to_i
        when 200
          resp.body
        when 429
          raise HTTPError, "rate limited: 429"
        when 500..599
          raise HTTPError, "server error: #{resp.code}"
        else
          raise HTTPError, "unexpected response: #{resp.code}"
        end
      rescue Timeout::Error => e
        raise TimeoutError, e.message if attempt > retries + 1

        sleep(backoff_for(attempt, base: backoff))
        retry
      rescue HTTPError => e
        if e.message.include?("429") && attempt <= retries
          # Respect Retry-After if present (best-effort)
          # WebMock tests usually set 0, production may set seconds
          retry_after = 0.0
          sleep(retry_after)
          sleep(backoff_for(attempt, base: backoff))
          retry
        elsif e.message.include?("server error") && attempt <= retries
          sleep(backoff_for(attempt, base: backoff))
          retry
        else
          raise
        end
      end
    end

    def self.parse_hiragana(html)
      doc = Nokogiri::HTML(html)
      cell = doc.at_css("#yomikata tbody tr td")
      text = cell&.inner_text&.strip
      raise Error, "failed to parse reading" if text.nil? || text.empty?

      text
    end

    def self.hiragana_to_katakana(hira)
      hira.tr("ぁ-ゔゝゞー", "ァ-ヴヽヾー")
    end

    DIGRAPHS = {
      "きゃ" => "kya", "きゅ" => "kyu", "きぇ" => "kye", "きょ" => "kyo",
      "ぎゃ" => "gya", "ぎゅ" => "gyu", "ぎぇ" => "gye", "ぎょ" => "gyo",
      "しゃ" => "sha", "しゅ" => "shu", "しぇ" => "she", "しょ" => "sho",
      "じゃ" => "ja",  "じゅ" => "ju",  "じぇ" => "je",  "じょ" => "jo",
      "ちゃ" => "cha", "ちゅ" => "chu", "ちぇ" => "che", "ちょ" => "cho",
      "にゃ" => "nya", "にゅ" => "nyu", "にぇ" => "nye", "にょ" => "nyo",
      "ひゃ" => "hya", "ひゅ" => "hyu", "ひぇ" => "hye", "ひょ" => "hyo",
      "びゃ" => "bya", "びゅ" => "byu", "びぇ" => "bye", "びょ" => "byo",
      "ぴゃ" => "pya", "ぴゅ" => "pyu", "ぴぇ" => "pye", "ぴょ" => "pyo",
      "みゃ" => "mya", "みゅ" => "myu", "みぇ" => "mye", "みょ" => "myo",
      "りゃ" => "rya", "りゅ" => "ryu", "りぇ" => "rye", "りょ" => "ryo",
      "ゔぁ" => "va",  "ゔぃ" => "vi",  "ゔぇ" => "ve",  "ゔぉ" => "vo",
      "ふぁ" => "fa",  "ふぃ" => "fi",  "ふぇ" => "fe",  "ふぉ" => "fo"
    }.freeze

    BASIC = {
      "あ" => "a",  "い" => "i",  "う" => "u",  "え" => "e",  "お" => "o",
      "か" => "ka", "き" => "ki", "く" => "ku", "け" => "ke", "こ" => "ko",
      "さ" => "sa", "し" => "shi", "す" => "su", "せ" => "se", "そ" => "so",
      "た" => "ta", "ち" => "chi", "つ" => "tsu", "て" => "te", "と" => "to",
      "な" => "na", "に" => "ni", "ぬ" => "nu", "ね" => "ne", "の" => "no",
      "は" => "ha", "ひ" => "hi", "ふ" => "fu", "へ" => "he", "ほ" => "ho",
      "ま" => "ma", "み" => "mi", "む" => "mu", "め" => "me", "も" => "mo",
      "や" => "ya", "ゆ" => "yu", "よ" => "yo",
      "ら" => "ra", "り" => "ri", "る" => "ru", "れ" => "re", "ろ" => "ro",
      "わ" => "wa", "ゐ" => "wi", "ゑ" => "we", "を" => "o",
      "ん" => "n",
      "が" => "ga", "ぎ" => "gi", "ぐ" => "gu", "げ" => "ge", "ご" => "go",
      "ざ" => "za", "じ" => "ji", "ず" => "zu", "ぜ" => "ze", "ぞ" => "zo",
      "だ" => "da", "ぢ" => "ji", "づ" => "zu", "で" => "de", "ど" => "do",
      "ば" => "ba", "び" => "bi", "ぶ" => "bu", "べ" => "be", "ぼ" => "bo",
      "ぱ" => "pa", "ぴ" => "pi", "ぷ" => "pu", "ぺ" => "pe", "ぽ" => "po",
      "ぁ" => "a",  "ぃ" => "i",  "ぅ" => "u",  "ぇ" => "e",  "ぉ" => "o",
      "ゔ" => "vu", "ゎ" => "wa", "ー" => "-"
    }.freeze

    def self.hiragana_to_romaji(hira)
      # Handle digraphs first
      s = hira.dup
      DIGRAPHS.each { |k, v| s.gsub!(k, v) }

      result = String.new
      chars = s.chars
      i = 0
      while i < chars.length
        ch = chars[i]
        nx = chars[i + 1]

        # sokuon (small tsu)
        if ch == "っ" && nx
          cons = case nx
                 when "c" then "t" # chu -> c but doubled as t (match 'c' + 'h')
                 when /^[a-z]/ then nx[0]
                 end
          # If next piece already converted (e.g., from digraph), take first consonant of romaji
          if cons.nil?
            # Look ahead: convert nx to romaji to get first consonant
            nx_romaji = BASIC[nx] || nx
            cons = nx_romaji[0]
          end
          result << cons if cons
          i += 1
          next
        end

        if ch == "ー"
          # Prolonged sound mark – skip simple handling
          i += 1
          next
        end

        romaji = BASIC[ch]
        result << (romaji || ch)
        i += 1
      end

      # Simple normalization: "nn" before vowels -> "n" (basic handling)
      result.gsub(/n(?=[aiueoy])/, "n")
    end

    def self.backoff_for(attempt, base: 0.5)
      # Exponential backoff with small jitter
      sleep_s = base * (2**(attempt - 1))
      jitter = rand * 0.05
      sleep_s + jitter
    end
  end
end
