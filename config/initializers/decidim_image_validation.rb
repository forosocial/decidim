# config/initializers/decidim_image_validation.rb
Rails.application.config.to_prepare do
  Decidim::Attachment.class_eval do
    validates :file, image_content: true, if: -> { file.attached? && file.image? }
  end

  Decidim::User.class_eval do
    validates :avatar, image_content: true, if: -> { avatar.attached? }
  end

  Decidim::Organization.class_eval do
    validates :logo, image_content: true, if: -> { logo.attached? }
    validates :favicon, image_content: true, if: -> { favicon.attached? }
    validates :official_img_footer, image_content: true, if: -> { official_img_footer.attached? }
  end

  if defined?(Decidim::EditorImage)
    Decidim::EditorImage.class_eval do
      validates :file, image_content: true, if: -> { file.attached? }
    end
  end
end
