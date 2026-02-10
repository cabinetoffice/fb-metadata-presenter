module MetadataPresenter
  class MaximumValidator < NumberValidator
    def invalid_answer?
      return if super

      if component.type == 'matrix'
        maximum_value = Float(component.validation[schema_key], exception: false)
        return false if maximum_value.blank?

        return matrix_numeric_values.any? { |value| value > maximum_value }
      end

      Float(user_answer, exception: false) > Float(component.validation[schema_key], exception: false)
    end
  end
end
