module MetadataPresenter
  class RequiredValidator < BaseValidator
    def invalid_answer?
      return matrix_required_invalid? if component.type == 'matrix'

      if component.type == 'multiupload'
        return user_answer[component.id].map(&:blank?).all?
      end

      user_answer.blank?
    end

    private

    def matrix_required_invalid?
      rows = Array(component.rows).map { |row| row['id'].to_s }
      return true if rows.empty?

      case component.mode
      when 'numeric'
        rows.any? do |row_id|
          row_answers = user_answer.fetch(row_id, {})
          row_answers.values.all?(&:blank?)
        end
      else
        rows.any? { |row_id| user_answer[row_id].blank? }
      end
    end
  end
end
