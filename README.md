# Kanji::Translator

漢字を「ひらがな」「カタカナ」「ローマ字（ヘボン式・簡易）」に変換し、スラッグも作れるシンプルなRubyライブラリです。読みは外部サイト（yomikatawa.com）の結果を取得して解析します。

> 注意: 本ライブラリはyomikatawa.comの非公式クライアントです。サイト構造の変更やレート制限の影響を受ける可能性があります。

## インストール

Ruby 3.2以上が必要です。

```bash
bundle add kanji-translator
```

GitHubから使う場合（任意）:

```ruby
# Gemfile
gem "kanji-translator", git: "https://github.com/dw-kodani/kanji-translator"
```

## クイックスタート

```ruby
require "kanji/translator"

Kanji::Translator.to_hira("漢字") #=> "かんじ"
Kanji::Translator.to_kata("漢字") #=> "カンジ"
Kanji::Translator.to_roma("漢字") #=> "kanji"
Kanji::Translator.to_slug("学校案内") #=> "gakkou-annai"
```

文字列メソッド（任意）:

```ruby
require "kanji/translator/core_ext/string"

"漢字".to_hira #=> "かんじ"
"学校案内".to_slug #=> "gakkou-annai"
```

## API

すべてのメソッドはネットワークを使う可能性があります（読み取得のため）。タイムアウトやリトライはオプションで調整できます。

- `Kanji::Translator.to_hira(text, timeout: 5, retries: 2, backoff: 0.5, user_agent: "kanji-translator/#{VERSION}")`
  - 読み（ひらがな）を返します。
- `Kanji::Translator.to_kata(text, **opts)`
  - ひらがな読みをカタカナに変換して返します。
- `Kanji::Translator.to_roma(text, **opts)`
  - 簡易ヘボン式のローマ字（ASCII、小文字）で返します。拗音/促音（ゃゅょ/っ）に対応。長音記号「ー」は無視します（例: おう→ou）。
- `Kanji::Translator.to_slug(text, separator: "-", downcase: true, collapse: true, **opts)`
  - `to_roma` の結果をスラッグ化します。
    - 非英数字を `separator` に置換、連続区切りを圧縮、前後の区切りをトリムします。
   - 内部で TinySegmenter による分かち書きを行い、語境界ごとにハイフン区切りします（例: "学校案内" → "gakkou-annai"）。

例（オプション）:

```ruby
Kanji::Translator.to_hira("漢字", timeout: 3, retries: 1)
Kanji::Translator.to_slug("東京タワー 2010") #=> "toukyou-tawa-2010"
Kanji::Translator.to_slug("Foo Bar", separator: "_") #=> "foo_bar"
```

### 例外

- `Kanji::Translator::TimeoutError` — 接続/読み取りタイムアウト
- `Kanji::Translator::HTTPError` — 429/5xxなどのHTTPエラー（一定回数リトライ後に発生）
- `Kanji::Translator::Error` — パース失敗などの基底例外

429（レート制限）や5xxは指数バックオフで自動リトライします。回数や待機は `retries`/`backoff` で調整可能です。

## 開発

```bash
bin/setup          # 依存をインストール
bundle exec rake   # RSpec + RuboCop を実行
bin/console        # IRBで試す
```

- Ruby: 3.2+（CIは 3.2/3.3/3.4）
- テスト: WebMockでHTTPをスタブしています（ネットワーク不要）。VCRの設定は入っていますが現状未使用です。
- コードスタイル: RuboCop（新Copは自動有効化）。自動修正は `-a`（安全）/`-A`（積極的）を使用。

## リリース

1. バージョン更新: `lib/kanji/translator/version.rb`
2. 変更履歴: `CHANGELOG.md` を更新
3. リリース: `bundle exec rake release`
   - Gitタグ作成 → push → Rubygemsへpush（MFA必須）

## ライセンス

MIT License。詳細は `LICENSE.txt` を参照してください。

## 貢献 / コード・オブ・コンダクト

Issue/Pull Requestは歓迎します。`CODE_OF_CONDUCT.md` に同意の上でご参加ください。連絡先はリポジトリのIssueをご利用ください。

## 謝辞

- 読み取得元: https://yomikatawa.com （非公式）
