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

    begin
      header = value.blob.open { |file| file.read(8) }.to_s.b

      valid = MAGIC_BYTES.any? do |_, magics|
        magics.any? { |magic| header.start_with?(magic.b) }
      end

      record.errors.add(attribute, :invalid_image_content) unless valid
    rescue ActiveStorage::Error, Errno::ENOENT, Errno::EACCES => e
      Rails.logger.error "ImageContentValidator: Error leyendo #{attribute} para #{record.class}##{record.id}: #{e.message}"
    end
  end
end
