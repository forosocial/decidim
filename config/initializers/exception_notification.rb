require "exception_notification/rails"

ExceptionNotification.configure do |config|
  config.add_notifier :email, {
    email_prefix: "[ERROR Decidim] ",
    sender_address: ENV["SMTP_FROM_EMAIL"],
    exception_recipients: ENV["EXCEPTION_RECIPIENTS"].to_s.split(",")
  }

  config.ignored_exceptions += %w[
    ActionController::RoutingError
    ActionController::UnknownFormat
    ActiveRecord::RecordNotFound
    Rack::QueryParser::InvalidParameterError
  ]
end
