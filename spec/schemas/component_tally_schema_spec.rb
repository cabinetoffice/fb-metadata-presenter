RSpec.describe 'component.tally schema' do
  it 'validates default tally metadata against component.tally schema' do
    expect {
      MetadataPresenter::ValidateSchema.validate(
        MetadataPresenter::DefaultMetadata['component.tally'],
        'component.tally'
      )
    }.not_to raise_error
  end
end
