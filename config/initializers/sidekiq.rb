# config/initializers/sidekiq.rb
# Añadido por pepeherr
# Gestión de colas

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }
  config.queues = %w[default mailers events exports]
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }
end