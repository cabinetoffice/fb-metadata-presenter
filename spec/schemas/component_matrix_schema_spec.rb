RSpec.describe 'component.matrix schema' do
  it 'validates default matrix metadata against component.matrix schema' do
    expect {
      MetadataPresenter::ValidateSchema.validate(
        MetadataPresenter::DefaultMetadata['component.matrix'],
        'component.matrix'
      )
    }.not_to raise_error
  end
end
