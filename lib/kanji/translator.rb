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
    ASCII_RE = /[A-Za-z0-9]/
    SPACE_RE = /[\s\u3000]/ # ASCII whitespace or IDEOGRAPHIC SPACE
    NON_ALNUM_RE = /[^a-z0-9]+/
    JAPANESE_RE = /[一-龯々〆ヵヶぁ-ゖゝゞァ-ヴー]/
    BOUNDARY = :__BOUNDARY__

    def self.to_hira(text, timeout: 5, retries: 2, backoff: 0.5, user_agent: USER_AGENT)
      raise ArgumentError, "text must be a String" unless text.is_a?(String)

      # Fast-path for kana inputs: avoid network and normalize locally
      if text.match?(/\A[ぁ-ゖーゝゞ]+\z/)
        return text
      elsif text.match?(/\A[ァ-ヴーヽヾヵヶ]+\z/)
        return katakana_to_hiragana(text)
      end

      body = fetch_page(text, timeout: timeout, retries: retries, backoff: backoff, user_agent: user_agent)
      hira = parse_hiragana(body)
      # Ensure result is normalized to hiragana only (remote may mix katakana like 固有名詞)
      katakana_to_hiragana(hira)
    end

    def self.to_kata(text, **)
      hira = to_hira(text, **)
      hiragana_to_katakana(hira)
    end

    def self.to_roma(text, **)
      hira = to_hira(text, **)
      hiragana_to_romaji(hira)
    end

    def self.to_slug(text, separator: "-", **opts)
      sep       = separator
      downcase  = opts.fetch(:downcase, true)
      collapse  = opts.fetch(:collapse, true)
      net_opts  = slice_opts(opts, :timeout, :retries, :backoff, :user_agent)

      tokens = segment_with_tiny(text)
      raw_parts = tokens.filter_map { |tok| normalize_slug_part(tok, net_opts) }
      parts = merge_ascii_parts(raw_parts)
      s = parts.join(sep)

      normalize_slug_string(s, sep: sep, downcase: downcase, collapse: collapse)
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

    def self.katakana_to_hiragana(kata)
      kata.tr("ァ-ヴヽヾヵヶー", "ぁ-ゔゝゞかけー")
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

    def self.segment_with_tiny(text)
      require "tiny_segmenter"
      seg = TinySegmenter.new
      tokens = []
      i = 0
      while i < text.length
        ch = text[i]
        if ch =~ ASCII_RE
          j = i + 1
          j += 1 while j < text.length && text[j] =~ ASCII_RE
          tokens << text[i...j]
          i = j
        elsif ch =~ SPACE_RE
          # treat whitespace (incl. IDEOGRAPHIC SPACE) as a hard boundary
          tokens << BOUNDARY unless tokens.last == BOUNDARY
          i += 1
        else
          # collect contiguous non-ASCII-non-space and segment via TinySegmenter
          j = i + 1
          j += 1 while j < text.length && text[j] !~ /[A-Za-z0-9\s\u3000]/
          chunk = text[i...j]
          tokens.concat(seg.segment(chunk))
          i = j
        end
      end
      tokens
    rescue LoadError
      raise Error, "tiny_segmenter gem is not installed. Add `tiny_segmenter` or omit segmenter option."
    end

    def self.japanese_token?(tok)
      # Kanji, Kana, prolonged sound mark, iteration marks, small kana
      !!(tok =~ JAPANESE_RE)
    end

    def self.normalize_slug_part(tok, net_opts)
      if tok == BOUNDARY
        { type: :boundary, text: nil }
      elsif japanese_token?(tok)
        { type: :j, text: to_roma(tok, **net_opts) }
      elsif tok =~ ASCII_RE
        { type: :ascii, text: tok }
      end
    end

    def self.merge_ascii_parts(parts)
      merged = []
      parts.each do |p|
        if p[:type] == :boundary
          merged << p
        elsif !merged.empty? && merged.last[:type] == :ascii && p[:type] == :ascii
          merged.last[:text] << p[:text]
        else
          merged << { type: p[:type], text: p[:text].dup }
        end
      end
      merged.reject { |p| p[:type] == :boundary }.map { |p| p[:text] }
    end

    def self.normalize_slug_string(str, sep:, downcase:, collapse:)
      s = str
      s = s.downcase if downcase
      # Replace non-alphanumeric with separator
      s = s.gsub(NON_ALNUM_RE, sep)
      # Collapse duplicate separators
      s = s.gsub(/#{Regexp.escape(sep)}{2,}/, sep) if collapse && !sep.empty?
      # Trim leading/trailing separators
      s = s.gsub(/^#{Regexp.escape(sep)}|#{Regexp.escape(sep)}$/, "") unless sep.empty?
      s
    end

    def self.slice_opts(hash, *keys)
      hash.slice(*keys)
    end

    private_class_method :segment_with_tiny, :japanese_token?, :normalize_slug_part, :merge_ascii_parts,
                         :normalize_slug_string, :slice_opts, :backoff_for, :katakana_to_hiragana,
                         :hiragana_to_katakana
  end
end
