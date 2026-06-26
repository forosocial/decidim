require "exception_notification/rails"

ExceptionNotification.configure do |config|

  # sólo se activa en producción aunque la gem esté cargada en todos los entornos
  config.add_notifier :email, {
    email_prefix: "[ERROR Decidim] ",
    sender_address: ENV["SMTP_FROM_EMAIL"],
    exception_recipients: ENV["EXCEPTION_RECIPIENTS"].to_s.split(",")
  } if Rails.env.production?
  
  config.ignored_exceptions += %w[
    ActionController::RoutingError
    ActionController::UnknownFormat
    ActionController::InvalidCrossOriginRequest
    ActiveRecord::RecordNotFound
    Rack::QueryParser::InvalidParameterError
    ActionController::InvalidAuthenticityToken
  ]

  # Ignorar solo el TypeError específico del bug de Decidim+remember_me
  config.ignore_if do |exception, options|
    exception.is_a?(TypeError) &&
      options[:env]["PATH_INFO"] == "/timeouts/seconds_until_timeout"
  end
 
end
