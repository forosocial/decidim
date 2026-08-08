# config/initializers/active_storage_rescue.rb
class ActiveStorageImageRescue
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue MiniMagick::Error, ActiveStorage::IntegrityError => e
    raise unless env["PATH_INFO"].to_s.start_with?("/rails/active_storage/representations/")

    Rails.logger.warn "ACTIVE_STORAGE_RESCUE: #{e.message} | Path: #{env["PATH_INFO"]} | IP: #{env["REMOTE_ADDR"]}"
    [302, { "Location" => "../public/icon.png", "Content-Type" => "text/html" }, []]branc
  end
end

Rails.application.config.middleware.insert_before ActionDispatch::ShowExceptions, ActiveStorageImageRescue
