# config/initializers/decidim_image_validation.rb
Rails.application.config.after_initialize do
  Decidim::Attachment.class_eval do
    validates :file, image_content: true, if: proc { file.attached? && file.image? }
  end

  Decidim::Organization.class_eval do
    validates :logo, image_content: true, if: proc { logo.attached? }
    validates :favicon, image_content: true, if: proc { favicon.attached? }
    validates :official_img_footer, image_content: true, if: proc { official_img_footer.attached? }
  end

  if defined?(Decidim::EditorImage)
    Decidim::EditorImage.class_eval do
      validates :file, image_content: true, if: proc { file.attached? }
    end
  end
end
