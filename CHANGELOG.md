## [Unreleased]

## [1.1.0] - 2025-09-08

- Fixed: `to_hira` の結果を必ずひらがなに正規化（返却HTMLにカタカナが混ざる場合の不整合を解消）。
- Improved: スラッグ生成の分割アルゴリズムを整理し、ASCII連結・空白（全角含む）境界を厳密化。混在テキストでの精度向上。
- Changed: `to_slug(text, separator: "-", **opts)` に整理（`separator` は直接キーワード、他は `**opts`）。互換性は維持。
- Refactor: 正規表現・正規化処理の定数化/関数抽出、内部メソッドを `private_class_method` 化。

## [1.0.0] - 2025-09-08

- Breaking: `to_slug` のデフォルト挙動を `segmenter: :tiny` に変更（語境界ごとにハイフン区切り）。
- Added: `segmenter: :space` オプションを追加。
- Added: 依存に `tiny_segmenter (~> 0.0.6)` を追加。
- Docs/Tests: READMEとRSpecを更新し新仕様を反映。

## [0.1.0] - 2025-09-08

- Initial release
