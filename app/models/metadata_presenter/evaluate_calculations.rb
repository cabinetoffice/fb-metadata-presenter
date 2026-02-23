module MetadataPresenter
  class EvaluateCalculations
    attr_reader :page, :service

    def initialize(page:, answers:, service:)
      @page = page
      @answers = (answers || {}).deep_dup
      @service = service
    end

    def call
      calculated_components.each do |component|
        value = calculate_value_for(component)
        next if value.nil?

        @answers[component.id] = value
      end

      @answers
    end

    private

    def calculated_components
      Array(page.components).select(&:calculated?)
    end

    def calculate_value_for(component)
      expression = component.calculation_expression
      return nil if expression.blank?

      resolved_expression = expression.gsub(/ref\((['"])([^'"]+)\1\)/) do
        resolved = resolve_reference(Regexp.last_match(2), component)
        resolved.nil? ? '0' : resolved.to_s
      end

      ArithmeticEvaluator.new(resolved_expression).call
    rescue StandardError => e
      Rails.logger.warn("[EvaluateCalculations] Unable to evaluate #{component.id}: #{e.class} #{e.message}")
      nil
    end

    def resolve_reference(reference, _component)
      dependency = dependency_index.fetch(reference, nil)
      source_component_uuid = dependency&.fetch('component_uuid', nil) || reference
      source_component = component_by_uuid(source_component_uuid)
      return nil unless source_component

      answer = @answers[source_component.id]
      answer = drill_down(answer, dependency&.fetch('path', nil))

      if answer.is_a?(Hash) && answer.key?('grand_total')
        answer = answer['grand_total']
      end

      number(answer)
    end

    def component_by_uuid(uuid)
      page = service.page_with_component(uuid)
      page&.find_component_by_uuid(uuid)
    end

    def dependency_index
      @dependency_index ||= calculated_components.each_with_object({}) do |component, index|
        Array(component.calculation_dependencies).each do |dependency|
          key = dependency['key'].presence || dependency['component_uuid']
          index[key] = dependency if key.present?
        end
      end
    end

    def drill_down(answer, path)
      return answer if path.blank?

      keys = Array(path)
      keys.reduce(answer) do |memo, key|
        break nil unless memo.respond_to?(:[])

        memo[key] || memo[key.to_s]
      end
    end

    def number(value)
      return value if value.is_a?(Numeric)

      Float(value, exception: false)
    end

    class ArithmeticEvaluator
      OP_PRECEDENCE = {
        '+' => 1,
        '-' => 1,
        '*' => 2,
        '/' => 2
      }.freeze

      def initialize(expression)
        @expression = expression.to_s
      end

      def call
        rpn = to_rpn(tokens)
        evaluate_rpn(rpn)
      end

      private

      def tokens
        raw = @expression.gsub(/\s+/, '')
        chars = raw.chars
        tokens = []

        until chars.empty?
          token = chars.shift

          if token.match?(/[0-9.]/)
            number = token
            while chars.first&.match?(/[0-9.]/)
              number << chars.shift
            end
            tokens << number
            next
          end

          if token == '-' && (tokens.empty? || OP_PRECEDENCE.key?(tokens.last) || tokens.last == '(')
            tokens << '0'
          end

          unless OP_PRECEDENCE.key?(token) || %w[( )].include?(token)
            raise ArgumentError, "Unsupported token '#{token}'"
          end

          tokens << token
        end

        tokens
      end

      def to_rpn(tokens)
        output = []
        operators = []

        tokens.each do |token|
          if numeric?(token)
            output << token
            next
          end

          if OP_PRECEDENCE.key?(token)
            while operators.any? && OP_PRECEDENCE.key?(operators.last) &&
                  OP_PRECEDENCE[operators.last] >= OP_PRECEDENCE[token]
              output << operators.pop
            end
            operators << token
            next
          end

          if token == '('
            operators << token
            next
          end

          if token == ')'
            output << operators.pop until operators.empty? || operators.last == '('
            raise ArgumentError, 'Mismatched brackets in expression' if operators.empty?

            operators.pop
          end
        end

        until operators.empty?
          op = operators.pop
          raise ArgumentError, 'Mismatched brackets in expression' if op == '('

          output << op
        end

        output
      end

      def evaluate_rpn(rpn)
        stack = []

        rpn.each do |token|
          if numeric?(token)
            stack << token.to_f
            next
          end

          b = stack.pop
          a = stack.pop
          raise ArgumentError, 'Invalid expression' if a.nil? || b.nil?

          stack << apply(a, b, token)
        end

        raise ArgumentError, 'Invalid expression' if stack.size != 1

        stack.first
      end

      def apply(a, b, operator)
        case operator
        when '+' then a + b
        when '-' then a - b
        when '*' then a * b
        when '/' then b.zero? ? 0 : a / b
        else
          raise ArgumentError, "Unsupported operator '#{operator}'"
        end
      end

      def numeric?(token)
        Float(token, exception: false).present?
      end
    end
  end
end
