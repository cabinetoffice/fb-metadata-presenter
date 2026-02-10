RSpec.describe MetadataPresenter::NumberValidator do
  subject(:validator) do
    described_class.new(page_answers:, component:)
  end
  let(:component) { page.components.first }
  let(:page_answers) { MetadataPresenter::PageAnswers.new(page, answers) }

  describe '#validate' do
    before do
      validator.valid?
    end

    context 'when is not a number' do
      %w[centuries . $ # % , 1.a 2.b].each do |invalid_answer|
        let(:answers) { { 'your-age_number_1' => invalid_answer } }
        let(:page) { service.find_page_by_url('/your-age') }

        it "returns invalid for '#{invalid_answer}'" do
          expect(validator).to_not be_valid
        end
      end
    end

    context 'when is a number' do
      %w[1 1.1 100].each do |valid_answer|
        let(:answers) { { 'your-age_number_1' => valid_answer } }
        let(:page) { service.find_page_by_url('/your-age') }

        it "returns valid for '#{valid_answer}'" do
          expect(validator).to be_valid
        end
      end
    end

    context 'when component is matrix numeric mode' do
      let(:page) do
        MetadataPresenter::Page.new(
          {
            '_id' => 'page.matrix-numeric',
            '_type' => 'page.singlequestion',
            '_uuid' => 'page-uuid-numeric',
            'url' => '/matrix-numeric',
            'components' => [
              {
                '_id' => 'matrix_numeric_1',
                '_type' => 'matrix',
                '_uuid' => 'matrix-numeric-uuid',
                'legend' => 'Matrix numeric question',
                'hint' => '',
                'name' => 'matrix_numeric_1',
                'mode' => 'numeric',
                'rows' => [{ 'id' => 'row-1', 'label' => 'Row 1' }],
                'columns' => [
                  { 'id' => 'column-1', 'label' => 'A' },
                  { 'id' => 'column-2', 'label' => 'B' }
                ],
                'validation' => { 'number' => true }
              }
            ]
          }
        )
      end

      context 'when any entered cell is not numeric' do
        let(:answers) do
          { 'matrix_numeric_1' => { 'row-1' => { 'column-1' => 'abc', 'column-2' => '' } } }
        end

        it 'returns invalid' do
          expect(validator).to_not be_valid
        end
      end

      context 'when all entered cells are numeric' do
        let(:answers) do
          { 'matrix_numeric_1' => { 'row-1' => { 'column-1' => '10.5', 'column-2' => '' } } }
        end

        it 'returns valid' do
          expect(validator).to be_valid
        end
      end
    end
  end
end
