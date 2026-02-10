module MetadataPresenter
  class NumberValidator < BaseValidator
    def invalid_answer?
      return matrix_invalid_answer? if component.type == 'matrix'

      Float(user_answer, exception: false).blank?
    end

    private

    def matrix_invalid_answer?
      return false unless component.mode == 'numeric'

      matrix_filled_values.any? { |value| Float(value, exception: false).blank? }
    end

    def matrix_filled_values
      user_answer.values.flat_map do |row_values|
        row_values.values
      end.reject(&:blank?)
    end

    def matrix_numeric_values
      matrix_filled_values.filter_map do |value|
        Float(value, exception: false)
      end
    end
  end
end
