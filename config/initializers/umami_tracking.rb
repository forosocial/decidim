# config/initializers/umami_tracking.rb
Decidim.configure do |config|
  config.extra_head_snippets = [
    "<script defer src=\"https://decidim.forosocial.org/umami/script.js\" data-website-id=\"#{ENV['UMAMI_WEBSITE_ID']}\"></script>"
  ]
end