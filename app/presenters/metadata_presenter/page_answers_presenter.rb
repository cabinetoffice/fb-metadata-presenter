module MetadataPresenter
  class PageAnswersPresenter
    FIRST_ANSWER = 0
    NO_USER_INPUT = %w[
      page.checkanswers
      page.confirmation
      page.content
      page.start
    ].freeze

    def self.map(view:, pages:, answers:)
      user_input_pages(pages).map { |page|
        Array(page.supported_components_by_type(:input)).map do |component|
          new(
            view:,
            component:,
            page:,
            answers:
          )
        end
      }.reject(&:empty?)
    end

    def self.user_input_pages(pages)
      pages.reject { |page| page.type.in?(NO_USER_INPUT) }
    end

    attr_reader :view, :component, :page, :answers

    delegate :url, to: :page
    delegate :humanised_title, to: :component

    def initialize(view:, component:, page:, answers:)
      @view = view
      @component = component
      @page = page
      @answers = answers

      @page_answers = PageAnswers.new(page, answers)
    end

    def answer
      value = @page_answers.send(component.id)

      return '' if value.blank?

      if self.class.private_method_defined?(component.type.to_sym)
        send(component.type.to_sym, value)
      else
        value
      end
    end

    def display_heading?(index)
      multiplequestions_page? && index == FIRST_ANSWER
    end

    def last_multiple_question?(index, presenters_count_for_page)
      multiplequestions_page? && index == presenters_count_for_page - 1
    end

    private

    def multiplequestions_page?
      page.type == 'page.multiplequestions'
    end

    def date(value)
      I18n.l(
        Date.civil(value.year.to_i, value.month.to_i, value.day.to_i),
        format: '%d %B %Y'
      )
    rescue Date::Error
      ''
    end

    def textarea(value)
      view.simple_format(value, {}, wrapper_tag: 'span')
    end

    def checkboxes(value)
      value.join('<br>').html_safe
    end

    def upload(file_hash)
      file_hash['original_filename']
    end

    def multiupload(multifile_hash)
      multifile_hash[component.id].map { |i| i['original_filename'] }.join('<br>').html_safe
    end

    def autocomplete(value)
      JSON.parse(value)['text']
    end

    def address(value)
      view.simple_format(
        value.to_a.join("\r\n"), {}, wrapper_tag: 'span'
      )
    end

    def matrix(value)
      return matrix_numeric(value) if component.mode == 'numeric'

      matrix_selection(value)
    end

    def matrix_selection(value)
      rows = Array(component.rows)
      columns = Array(component.columns)

      return matrix_selection_table(value, rows, columns) if render_matrix_selection_table?(rows, columns)

      column_labels = Array(component.columns).each_with_object({}) do |column, labels|
        labels[column['id'].to_s] = column['label']
      end

      lines = rows.filter_map do |row|
        row_id = row['id'].to_s
        selected_columns = matrix_selection_row_values(value, row_id)
        next if selected_columns.empty?

        row_label = ERB::Util.h(row['label'])
        selected_labels = selected_columns.map do |selected_column|
          ERB::Util.h(column_labels[selected_column] || selected_column)
        end.join(', ')
        "#{row_label}: #{selected_labels}"
      end

      lines.join('<br>').html_safe
    end

    def render_matrix_selection_table?(rows, columns)
      rows.length > 1 || columns.length > 3
    end

    def matrix_selection_table(value, rows, columns)
      row_heading = component.respond_to?(:row_heading) ? component.row_heading : nil
      first_column_heading = row_heading.presence || ''

      view.content_tag(:table, class: 'govuk-table') do
        thead = view.content_tag(:thead, class: 'govuk-table__head') do
          view.content_tag(:tr, class: 'govuk-table__row') do
            first_header = view.content_tag(:th, first_column_heading, scope: 'col', class: 'govuk-table__header')
            column_headers = columns.map do |column|
              view.content_tag(:th, column['label'], scope: 'col', class: 'govuk-table__header')
            end.join.html_safe
            first_header + column_headers
          end
        end

        tbody = view.content_tag(:tbody, class: 'govuk-table__body') do
          rows.map do |row|
            row_id = row['id'].to_s
            selected_columns = matrix_selection_row_values(value, row_id)
            view.content_tag(:tr, class: 'govuk-table__row') do
              row_header = view.content_tag(:th, row['label'], scope: 'row', class: 'govuk-table__header')
              cells = columns.map do |column|
                checked = selected_columns.include?(column['id'].to_s)
                view.content_tag(:td, checked ? '✓' : '', class: 'govuk-table__cell')
              end.join.html_safe
              row_header + cells
            end
          end.join.html_safe
        end

        thead + tbody
      end
    end

    def matrix_selection_row_values(value, row_id)
      row_value = value[row_id]
      return [] if row_value.blank?

      Array(row_value).map(&:to_s).reject(&:blank?)
    end

    def matrix_numeric(value)
      columns = Array(component.columns)
      rows = Array(component.rows)

      view.content_tag(:table, class: 'govuk-table') do
        thead = view.content_tag(:thead, class: 'govuk-table__head') do
          view.content_tag(:tr, class: 'govuk-table__row') do
            first_header = view.content_tag(:th, '', scope: 'col', class: 'govuk-table__header')
            column_headers = columns.map do |column|
              view.content_tag(:th, column['label'], scope: 'col', class: 'govuk-table__header')
            end.join.html_safe
            first_header + column_headers
          end
        end

        tbody = view.content_tag(:tbody, class: 'govuk-table__body') do
          rows.map do |row|
            row_id = row['id'].to_s
            view.content_tag(:tr, class: 'govuk-table__row') do
              row_header = view.content_tag(:th, row['label'], scope: 'row', class: 'govuk-table__header')
              cells = columns.map do |column|
                column_id = column['id'].to_s
                cell_value = value.dig(row_id, column_id)
                view.content_tag(:td, cell_value.nil? ? '' : cell_value, class: 'govuk-table__cell')
              end.join.html_safe
              row_header + cells
            end
          end.join.html_safe
        end

        thead + tbody
      end
    end
  end
end
