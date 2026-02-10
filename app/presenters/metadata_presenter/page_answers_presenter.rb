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
      column_labels = Array(component.columns).each_with_object({}) do |column, labels|
        labels[column['id'].to_s] = column['label']
      end

      lines = Array(component.rows).filter_map do |row|
        row_id = row['id'].to_s
        selected_column = value[row_id]
        next if selected_column.blank?

        row_label = ERB::Util.h(row['label'])
        selected_label = ERB::Util.h(column_labels[selected_column.to_s] || selected_column)
        "#{row_label}: #{selected_label}"
      end

      lines.join('<br>').html_safe
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
