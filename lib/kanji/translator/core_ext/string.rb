# frozen_string_literal: true

require "kanji/translator"

class String
  def to_hira(**)
    Kanji::Translator.to_hira(self, **)
  end

  def to_kata(**)
    Kanji::Translator.to_kata(self, **)
  end

  def to_roma(**)
    Kanji::Translator.to_roma(self, **)
  end

  def to_slug(**)
    Kanji::Translator.to_slug(self, **)
  end
end
