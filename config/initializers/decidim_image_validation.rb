# config/initializers/decidim_image_validation.rb
Rails.application.config.to_prepare do
  # Adjuntos de propuestas, procesos, etc.
  Decidim::Attachment.class_eval do
    validates :file, image_content: true, if: -> { file.attached? && file.image? }
  end

  # Avatares de usuario
  Decidim::User.class_eval do
    validates :avatar, image_content: true, if: -> { avatar.attached? }
  end

  # Imágenes de organización
  Decidim::Organization.class_eval do
    validates :logo, image_content: true, if: -> { logo.attached? }
    validates :favicon, image_content: true, if: -> { favicon.attached? }
    validates :highlighted_content_banner_image, image_content: true, if: -> { highlighted_content_banner_image.attached? }
    validates :official_img_header, image_content: true, if: -> { official_img_header.attached? }
    validates :official_img_footer, image_content: true, if: -> { official_img_footer.attached? }
  end

  # Imágenes del editor WYSIWYG
  if defined?(Decidim::EditorImage)
    Decidim::EditorImage.class_eval do
      validates :file, image_content: true, if: -> { file.attached? }
    end
  end
end
