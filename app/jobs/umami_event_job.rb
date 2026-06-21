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
# IMPORTANTE: Umami usa la librería "isbot" para descartar peticiones de bots,
# devolviendo un falso 200 OK con {"beep":"boop"} sin guardar el evento.
# El User-Agent NO debe contener palabras como "bot", "crawler", "spider" o
# "tracker" (incluso en "Decidim-Umami-Tracker" se detectaba como bot).
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
    # User-Agent neutro, sin palabras que disparen la detección de bots de Umami (isbot).
    request["User-Agent"] = "Decidim/0.31.4 (+https://decidim.forosocial.org)"
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
    Rails.logger.info("Umami event sent: #{event_name} - #{response.code} - #{response.body}")
  rescue StandardError => e
    Rails.logger.warn("Umami tracking failed: #{e.message}")
  end
end