RSpec.describe MetadataPresenter::EvaluateCalculations do
  subject(:result) { described_class.new(page:, answers:, service:).call }

  let(:service) { MetadataPresenter::Service.new(service_metadata) }
  let(:page) { service.find_page_by_uuid('page-target') }

  let(:answers) do
    {
      'source_number_1' => '10',
      'source_number_2' => 4
    }
  end

  let(:service_metadata) do
    {
      'pages' => [
        {
          '_id' => 'page.source',
          '_type' => 'page.singlequestion',
          '_uuid' => 'page-source',
          'url' => '/source',
          'heading' => 'Source',
          'components' => [
            {
              '_id' => 'source_number_1',
              '_type' => 'number',
              '_uuid' => 'source-number-uuid-1',
              'label' => 'Source number 1',
              'name' => 'source_number_1',
              'validation' => { 'required' => true, 'number' => true }
            },
            {
              '_id' => 'source_number_2',
              '_type' => 'number',
              '_uuid' => 'source-number-uuid-2',
              'label' => 'Source number 2',
              'name' => 'source_number_2',
              'validation' => { 'required' => true, 'number' => true }
            },
            {
              '_id' => 'source_tally_1',
              '_type' => 'tally',
              '_uuid' => 'source-tally-uuid',
              'legend' => 'Source tally',
              'name' => 'source_tally_1',
              'rows' => [{ 'id' => 'row-1', 'label' => 'Row 1' }],
              'columns' => [{ 'id' => 'column-1', 'label' => 'Column 1' }],
              'validation' => { 'required' => true }
            }
          ]
        },
        {
          '_id' => 'page.target',
          '_type' => 'page.singlequestion',
          '_uuid' => 'page-target',
          'url' => '/target',
          'heading' => 'Target',
          'components' => [
            {
              '_id' => 'target_number_1',
              '_type' => 'number',
              '_uuid' => 'target-number-uuid',
              'label' => 'Target number',
              'name' => 'target_number_1',
              'validation' => { 'required' => true, 'number' => true },
              'calculation' => target_calculation
            }
          ]
        }
      ]
    }
  end

  let(:target_calculation) do
    {
      'enabled' => true,
      'expression' => 'ref("source-number-uuid-1")',
      'dependencies' => [
        {
          'key' => 'source-number-uuid-1',
          'page_uuid' => 'page-source',
          'component_uuid' => 'source-number-uuid-1'
        }
      ]
    }
  end

  describe '#call' do
    it 'returns answers merged with evaluated calculated component values' do
      expect(result).to include('target_number_1' => 10.0)
      expect(result).to include('source_number_1' => '10', 'source_number_2' => 4)
    end

    it 'does not mutate the original answers hash' do
      original_answers = answers.deep_dup
      result

      expect(answers).to eq(original_answers)
    end

    context 'when calculation is disabled' do
      let(:target_calculation) do
        {
          'enabled' => false,
          'expression' => 'ref("source-number-uuid-1") * 2',
          'dependencies' => [{ 'component_uuid' => 'source-number-uuid-1' }]
        }
      end

      it 'returns answers unchanged' do
        expect(result).to eq(answers)
      end
    end

    context 'with arithmetic precedence and brackets' do
      let(:target_calculation) do
        {
          'enabled' => true,
          'expression' => '(ref("source-number-uuid-1") + ref("source-number-uuid-2")) * 2 - 3',
          'dependencies' => [
            { 'component_uuid' => 'source-number-uuid-1' },
            { 'component_uuid' => 'source-number-uuid-2' }
          ]
        }
      end

      it 'evaluates using operator precedence and parentheses' do
        expect(result['target_number_1']).to eq(25.0)
      end
    end

    context 'when a reference is missing from answers' do
      let(:answers) { { 'source_number_2' => 4 } }
      let(:target_calculation) do
        {
          'enabled' => true,
          'expression' => 'ref("source-number-uuid-1") + 5',
          'dependencies' => [{ 'component_uuid' => 'source-number-uuid-1' }]
        }
      end

      it 'treats the missing reference as zero' do
        expect(result['target_number_1']).to eq(5.0)
      end
    end

    context 'when dependency key maps to nested path values' do
      let(:answers) do
        {
          'source_tally_1' => {
            'row_totals' => { 'row-1' => 7 },
            'grand_total' => 12
          }
        }
      end

      let(:target_calculation) do
        {
          'enabled' => true,
          'expression' => 'ref("tally-row-total") + 1',
          'dependencies' => [
            {
              'key' => 'tally-row-total',
              'component_uuid' => 'source-tally-uuid',
              'path' => %w[row_totals row-1]
            }
          ]
        }
      end

      it 'resolves the nested value via dependency path' do
        expect(result['target_number_1']).to eq(8.0)
      end
    end

    context 'when reference points to a hash answer with grand_total' do
      let(:answers) do
        {
          'source_tally_1' => {
            'row_totals' => { 'row-1' => 7 },
            'grand_total' => 12
          }
        }
      end

      let(:target_calculation) do
        {
          'enabled' => true,
          'expression' => 'ref("source-tally-uuid") / 3',
          'dependencies' => [
            {
              'component_uuid' => 'source-tally-uuid'
            }
          ]
        }
      end

      it 'uses the grand_total numeric value' do
        expect(result['target_number_1']).to eq(4.0)
      end
    end

    context 'when expression divides by zero' do
      let(:target_calculation) do
        {
          'enabled' => true,
          'expression' => 'ref("source-number-uuid-1") / 0',
          'dependencies' => [{ 'component_uuid' => 'source-number-uuid-1' }]
        }
      end

      it 'returns zero instead of raising an error' do
        expect(result['target_number_1']).to eq(0)
      end
    end

    context 'when expression contains invalid tokens' do
      let(:target_calculation) do
        {
          'enabled' => true,
          'expression' => 'ref("source-number-uuid-1") + abc',
          'dependencies' => [{ 'component_uuid' => 'source-number-uuid-1' }]
        }
      end

      it 'logs a warning and leaves the calculated answer unset' do
        expect(Rails.logger).to receive(:warn).with(/Unable to evaluate target_number_1/)

        expect(result).not_to have_key('target_number_1')
      end
    end

    context 'when dependencies are omitted but expression uses direct uuid refs' do
      let(:target_calculation) do
        {
          'enabled' => true,
          'expression' => 'ref("source-number-uuid-1") + ref("source-number-uuid-2")',
          'dependencies' => []
        }
      end

      it 'falls back to using the ref value as component uuid' do
        expect(result['target_number_1']).to eq(14.0)
      end
    end
  end
end
