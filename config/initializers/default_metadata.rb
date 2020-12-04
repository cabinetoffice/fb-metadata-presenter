Rails.application.config.default_metadata_directory = File.join(
  File.dirname(__FILE__),
  '../../default_metadata'
)

Rails.application.config.default_metadata = {}

Rails.logger.info('Loading default metadata')
default_metadata = Dir.glob("#{Rails.application.config.default_metadata_directory}/*/**")
default_metadata.each do |metadata_file|
  metadata = JSON.parse(File.read(metadata_file))
  Rails.logger.info(metadata['_id'])
  Rails.application.config.default_metadata[metadata['_id']] = metadata
end

Rails.logger.info(
  "Total loaded default metadata => #{Rails.application.config.default_metadata.count}"
)
