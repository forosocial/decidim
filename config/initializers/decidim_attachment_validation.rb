# config/initializers/decidim_attachment_validation.rb
Rails.application.config.to_prepare do
  Decidim::Attachment.class_eval do
    validates :file, image_content: true, if: -> { file.image? }
  end
end