RSpec.describe MetadataPresenter::PageAnswersPresenter do
  subject(:presenter) do
    described_class.new(
      view:,
      page:,
      component:,
      answers:
    )
  end
  let(:view) { MetadataPresenter::PagesController.new.view_context }
  let(:pages) { service.pages }
  let(:component) { page.components.first }

  describe '.map' do
    let(:answers) { {} }
    let(:page_answers) do
      described_class.map(view:, pages:, answers:)
    end

    it 'returns a collection of page answers presenters' do
      expect(page_answers.flatten).to all(be_a(MetadataPresenter::PageAnswersPresenter))
    end

    it 'groups page answer presenters by page' do
      page_answers.each do |page|
        expect(page.map(&:page).collect(&:id).uniq.length).to be 1
      end
    end
  end

  describe '#answer' do
    context 'when component is a textarea' do
      let(:page) { service.find_page_by_url('/family-hobbies') }

      context 'when there is an answer' do
        let(:answers) do
          { component.id => "Play Star Wars\r\nWatch Mandalorian" }
        end

        it 'returns formatted value' do
          expect(presenter.answer).to eq(
            %(<span>Play Star Wars\n<br />Watch Mandalorian</span>)
          )
        end
      end

      context 'when there is no answer' do
        let(:answers) do
          {}
        end

        it 'returns empty string' do
          expect(presenter.answer).to eq('')
        end
      end
    end

    context 'when component is a date' do
      let(:page) { service.find_page_by_url('/holiday') }
      context 'when there is an answer' do
        let(:answers) do
          {
            "#{component.id}(3i)" => '01',
            "#{component.id}(2i)" => '07',
            "#{component.id}(1i)" => '2021'
          }
        end

        it 'returns formatted date' do
          expect(presenter.answer).to eq('01 July 2021')
        end
      end

      context 'when there is no answer' do
        let(:answers) { {} }

        it 'returns empty string' do
          expect(presenter.answer).to eq('')
        end
      end

      # shouldn't happen, but save and return bypasses validation
      context 'when presenting an invalid date' do
        let(:answers) do
          {
            "#{component.id}(3i)" => '35',
            "#{component.id}(2i)" => '35',
            "#{component.id}(1i)" => '2021'
          }
        end

        it 'returns empty string' do
          expect(presenter.answer).to eq('')
        end
      end
    end

    context 'when component is a checkbox' do
      let(:page) { service.find_page_by_url('/burgers') }
      context 'when there are two boxes checked' do
        let(:answers) do
          { component.id => ['Chicken, cheese, tomato', 'Mozzarella, cheddar, feta'] }
        end

        it 'returns formatted answer' do
          expect(presenter.answer).to eq('Chicken, cheese, tomato<br>Mozzarella, cheddar, feta')
        end
      end
    end

    context 'when component is upload' do
      let(:page) { service.find_page_by_url('dog-picture') }

      context 'when there is an answer' do
        let(:answers) do
          {
            component.id => {
              'tempfile' => '#<File:0x00007fea860712c8>',
              'original_filename' => 'computer_says_no.gif',
              'content_type' => 'image/gif',
              'headers' => 'Content-Type: image/gif'
            }
          }
        end

        it 'returns the original file name' do
          expect(presenter.answer).to eq('computer_says_no.gif')
        end
      end
    end

    context 'when component is normal formatting' do
      let(:page) { service.find_page_by_url('/name') }
      let(:answers) { { component.id => 'Mando' } }

      it 'returns value' do
        expect(presenter.answer).to eq('Mando')
      end
    end

    context 'when component is matrix in selection mode' do
      let(:page) do
        MetadataPresenter::Page.new(
          {
            '_id' => 'page.matrix',
            '_type' => 'page.singlequestion',
            '_uuid' => 'page-uuid',
            'url' => '/matrix',
            'components' => [
              {
                '_id' => 'matrix_1',
                '_type' => 'matrix',
                '_uuid' => 'matrix-uuid',
                'legend' => 'Matrix question',
                'hint' => '',
                'name' => 'matrix_1',
                'mode' => 'selection',
                'rows' => [{ 'id' => 'row-1', 'label' => 'Row 1' }],
                'columns' => [
                  { 'id' => 'column-1', 'label' => 'Yes' },
                  { 'id' => 'column-2', 'label' => 'No' }
                ],
                'validation' => { 'required' => true }
              }
            ]
          }
        )
      end
      let(:component) { page.components.first }
      let(:answers) { { component.id => { 'row-1' => 'column-2' } } }

      it 'returns row to selected column label mapping' do
        expect(presenter.answer).to eq('Row 1: No')
      end
    end

    context 'when component is matrix in selection mode with multiple rows' do
      let(:page) do
        MetadataPresenter::Page.new(
          {
            '_id' => 'page.matrix.table',
            '_type' => 'page.singlequestion',
            '_uuid' => 'page-uuid-table',
            'url' => '/matrix-table',
            'components' => [
              {
                '_id' => 'matrix_table_1',
                '_type' => 'matrix',
                '_uuid' => 'matrix-table-uuid',
                'legend' => 'Matrix table question',
                'hint' => '',
                'name' => 'matrix_table_1',
                'mode' => 'selection',
                'rows' => [
                  { 'id' => 'row-1', 'label' => 'Pre-sifting' },
                  { 'id' => 'row-2', 'label' => 'Sifting' }
                ],
                'columns' => [
                  { 'id' => 'column-1', 'label' => 'Yes' },
                  { 'id' => 'column-2', 'label' => 'No' },
                  { 'id' => 'column-3', 'label' => 'Partial' },
                  { 'id' => 'column-4', 'label' => 'N/A' }
                ],
                'validation' => { 'required' => true }
              }
            ]
          }
        )
      end
      let(:component) { page.components.first }
      let(:answers) do
        {
          component.id => {
            'row-1' => 'column-1',
            'row-2' => 'column-4'
          }
        }
      end

      it 'returns a table rendering for matrix selection answers' do
        expect(presenter.answer).to include('<table')
        expect(presenter.answer).to include('Pre-sifting')
        expect(presenter.answer).to include('Sifting')
        expect(presenter.answer).to include('✓')
      end
    end

    context 'when component is matrix in numeric mode' do
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
                'validation' => { 'required' => true }
              }
            ]
          }
        )
      end
      let(:component) { page.components.first }
      let(:answers) do
        { component.id => { 'row-1' => { 'column-1' => '10.5', 'column-2' => '' } } }
      end

      it 'returns a table rendering for matrix numeric answers' do
        expect(presenter.answer).to include('<table')
        expect(presenter.answer).to include('Row 1')
        expect(presenter.answer).to include('10.5')
      end
    end

    context 'when there is no answer' do
      let(:page) { service.find_page_by_url('/name') }
      let(:answers) { {} }

      it 'returns empty string' do
        expect(presenter.answer).to eq('')
      end
    end
  end

  describe '#display_heading?' do
    let(:answers) { {} }

    context 'when multiple question page' do
      let(:page) do
        service.find_page_by_url('/star-wars-knowledge')
      end

      context 'when first answer' do
        let(:index) { 0 }

        it 'returns true' do
          expect(subject.display_heading?(index)).to be_truthy
        end
      end

      context 'when not first answer' do
        let(:index) { 1 }

        it 'returns false' do
          expect(subject.display_heading?(index)).to be_falsey
        end
      end
    end

    context 'when any other page' do
      let(:page) do
        service.find_page_by_url('/burgers')
      end
      let(:index) { 0 }

      it 'returns false' do
        expect(subject.display_heading?(index)).to be_falsey
      end
    end
  end

  describe '#last_multiple_question?' do
    let(:answers) { {} }

    context 'when multiple question page' do
      let(:page) do
        service.find_page_by_url('/star-wars-knowledge')
      end
      let(:page_answers_count) do
        page.supported_components_by_type(:input).size
      end

      context 'when last question' do
        let(:index) { page_answers_count - 1 }

        it 'returns true' do
          expect(subject.last_multiple_question?(index, page_answers_count)).to be_truthy
        end
      end

      context 'when only one question on the page' do
        let(:index) { 0 }

        it 'returns true' do
          expect(subject.last_multiple_question?(index, 1)).to be_truthy
        end
      end

      context 'when not the last question' do
        let(:index) { 0 }

        it 'returns false' do
          expect(subject.last_multiple_question?(index, page_answers_count)).to be_falsey
        end
      end
    end

    context 'when not multiple question page' do
      let(:page) do
        service.find_page_by_url('/burgers')
      end
      let(:page_answers_count) do
        page.supported_components_by_type(:input).size
      end
      let(:index) { 0 }

      it 'returns false' do
        expect(subject.last_multiple_question?(index, page_answers_count)).to be_falsey
      end
    end
  end
end
