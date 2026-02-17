module MetadataPresenter
  class RequiredValidator < BaseValidator
    def invalid_answer?
      return matrix_required_invalid? if component.type == 'matrix'
      return tally_required_invalid? if component.type == 'tally'

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

    def tally_required_invalid?
      rows = Array(component.rows)
      columns = Array(component.columns)
      return true if rows.empty?

      rows.any? do |row|
        row_id = row['id'].to_s
        row_answers = user_answer.fetch('cells', {}).fetch(row_id, {})
        answerable_column_ids = answerable_tally_column_ids(row, columns)
        next false if answerable_column_ids.empty?

        answerable_column_ids.all? { |column_id| row_answers[column_id].blank? }
      end
    end

    def answerable_tally_column_ids(row, columns)
      row_id = row['id'].to_s
      active = Array(row['active_column_ids']).map(&:to_s)
      active = columns.map { |column| column['id'].to_s } if active.empty?

      active.reject do |column_id|
        override = component.cell_overrides&.[]("#{row_id}:#{column_id}")
        override == true || (override.is_a?(Hash) && override['disabled'] == true)
      end
    end
  end
end
