# frozen_string_literal: true

# Envía eventos personalizados a Umami Analytics (self-hosted) vía su API HTTP /api/send.
#
# Se usa para registrar acciones de participación en Decidim (por ejemplo,
# creación de comentarios) que no generan un page view propio, ya que se
# envían vía AJAX/Turbo sin recargar la página.
#
# Motivación: permite comparar el nivel de participación (no solo de
# visitas) entre los distintos componentes de "Acuerdo Ecosocial"
# (Pactos, Conflictos, Propuestas) en los dashboards de Umami.
#
# Documentación de la API: https://docs.umami.is/docs/api/sending-stats
#
# Uso:
#   UmamiEventJob.perform_later("comentario_creado", { tipo: "Pacto", commentable_id: 15 }, "/processes/acuerdoecosocial")

class UmamiEventJob < ApplicationJob
  queue_as :default

  def perform(event_name, data, url)
    uri = URI("https://decidim.forosocial.org/umami/api/send")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    # Umami descarta silenciosamente las peticiones sin User-Agent válido.
    request["User-Agent"] = "Decidim-Umami-Tracker/1.0"
    request.body = {
      type: "event",
      payload: {
        website: ENV["UMAMI_WEBSITE_ID"],
        url: url,
        name: event_name,
        data: data
      }
    }.to_json

    response = http.request(request)
    Rails.logger.info("Umami event sent: #{event_name} - #{response.code}")
  rescue StandardError => e
    # No queremos que un fallo de Umami afecte al flujo normal de Decidim,
    # así que solo lo registramos en el log.
    Rails.logger.warn("Umami tracking failed: #{e.message}")
  end
end