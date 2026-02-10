module MetadataPresenter
  class MinimumValidator < NumberValidator
    def invalid_answer?
      return if super

      if component.type == 'matrix'
        minimum_value = Float(component.validation[schema_key], exception: false)
        return false if minimum_value.blank?

        return matrix_numeric_values.any? { |value| value < minimum_value }
      end

      Float(user_answer, exception: false) < Float(component.validation[schema_key], exception: false)
    end
  end
end
