# app/validators/image_content_validator.rb
class ImageContentValidator < ActiveModel::EachValidator
  MAGIC_BYTES = {
    "image/png" => ["\x89PNG\r\n\x1A\n"],
    "image/jpeg" => ["\xFF\xD8\xFF"],
    "image/gif" => %w(GIF87a GIF89a),
    "image/webp" => ["RIFF"]
  }.freeze

  def validate_each(record, attribute, value)
    return unless value.attached? && value.image?

    value.download do |file|
      header = file.read(8).to_s.b
      valid = MAGIC_BYTES.any? { |_, magics| magics.any? { |m| header.start_with?(m.b) } }

      unless valid
        record.errors.add(attribute, :invalid_image_content)
        value.purge
      end
    end
  rescue StandardError => e
    Rails.logger.error "ImageContentValidator error: #{e.message}"
    record.errors.add(attribute, :invalid_image_content)
  end
end
