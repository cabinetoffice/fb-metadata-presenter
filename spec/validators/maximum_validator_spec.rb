RSpec.describe MetadataPresenter::MaximumValidator do
  subject(:validator) do
    described_class.new(page_answers:, component:)
  end
  let(:page) do
    meta = service.find_page_by_url('/your-age')
    meta['components'][0]['validation'] = maximum_validation
    meta
  end
  let(:component) { page.components.first }
  let(:page_answers) { MetadataPresenter::PageAnswers.new(page, answers) }
  let(:maximum_validation) { { 'maximum' => '5' } }

  describe '#validate' do
    before do
      validator.valid?
    end

    context 'when invalid answer' do
      %w[5.6 100].each do |invalid_answer|
        let(:answers) { { 'your-age_number_1' => invalid_answer } }

        it "returns invalid for '#{invalid_answer}'" do
          expect(validator).to_not be_valid
        end
      end
    end

    context 'when valid answer' do
      %w[0.1 1 3.2 5].each do |valid_answer|
        let(:answers) { { 'your-age_number_1' => valid_answer } }

        it "returns valid for '#{valid_answer}'" do
          expect(validator).to be_valid
        end
      end
    end

    context 'when not a number' do
      let(:answers) { { 'your-age_number_1' => 'i am not a number' } }

      it 'returns valid' do
        expect(validator).to be_valid
      end
    end

    context 'when component is matrix numeric mode' do
      let(:page) do
        MetadataPresenter::Page.new(
          {
            '_id' => 'page.matrix-max',
            '_type' => 'page.singlequestion',
            '_uuid' => 'page-uuid-max',
            'url' => '/matrix-max',
            'components' => [
              {
                '_id' => 'matrix_max_1',
                '_type' => 'matrix',
                '_uuid' => 'matrix-max-uuid',
                'legend' => 'Matrix numeric question',
                'hint' => '',
                'name' => 'matrix_max_1',
                'mode' => 'numeric',
                'rows' => [{ 'id' => 'row-1', 'label' => 'Row 1' }],
                'columns' => [
                  { 'id' => 'column-1', 'label' => 'A' },
                  { 'id' => 'column-2', 'label' => 'B' }
                ],
                'validation' => { 'maximum' => '5' }
              }
            ]
          }
        )
      end

      context 'when any entered cell is above maximum' do
        let(:answers) do
          { 'matrix_max_1' => { 'row-1' => { 'column-1' => '5.1', 'column-2' => '' } } }
        end

        it 'returns invalid' do
          expect(validator).to_not be_valid
        end
      end

      context 'when all entered cells are at or below maximum' do
        let(:answers) do
          { 'matrix_max_1' => { 'row-1' => { 'column-1' => '5', 'column-2' => '2.3' } } }
        end

        it 'returns valid' do
          expect(validator).to be_valid
        end
      end
    end
  end
end
