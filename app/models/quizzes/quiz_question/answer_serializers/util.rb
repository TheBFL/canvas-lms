# frozen_string_literal: true

#
# Copyright (C) 2013 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

require "sanitize"

module Quizzes::QuizQuestion::AnswerSerializers
  module Util
    MaxTextualAnswerLength = 16.kilobytes

    class << self
      def blank_id(blank)
        AssessmentQuestion.variable_id(blank)
      end

      # Cast a numerical value to an Integer.
      #
      # @return [Integer|NilClass]
      #   nil if the parameter isn't really an integer.
      def to_integer(number)
        Integer(number, exception: false)
      end

      # Cast a localized string number to a BigDecimal
      #
      # @return [BigDecimal]
      def i18n_to_decimal(value)
        separator = I18n.t("number.format.separator")
        delimiter = I18n.t("number.format.delimiter")

        to_decimal(value.gsub(delimiter, "").gsub(separator, "."))
      end

      # Cast a BigDecimal to a localized string
      #
      # @return [String]
      def decimal_to_i18n(value)
        separator = I18n.t("number.format.separator")
        delimiter = I18n.t("number.format.delimiter")

        value.to_s.gsub(delimiter, "").gsub(separator, ".")
      end

      # Convert a value to a BigDecimal.
      #
      # @return [BigDecimal]
      def to_decimal(value)
        BigDecimal(value.to_s)
      rescue ArgumentError
        BigDecimal("0.0")
      end

      def to_boolean(flag)
        Canvas::Plugin.value_to_boolean(flag)
      end

      # See Util.MaxTextualAnswerLength for the threshold.
      def text_too_long?(text)
        text.to_s.length >= MaxTextualAnswerLength
      end

      def sanitize_html(html)
        Sanitize.clean((html || "").to_s, CanvasSanitize::SANITIZE)
      end

      def sanitize_text(text)
        (text || "").to_s.strip.downcase
      end
    end
  end
end
