cat config/initializers/decidim.rb 
# frozen_string_literal: true

Decidim.configure do |config|
  # Nombre de la aplicación
  config.application_name = "Foro Social Más Allá del Crecimiento"

  # Email del remitente por defecto
  config.mailer_sender = ENV["SMTP_FROM_EMAIL"]

  # Locales disponibles
  config.available_locales = [:es, :ca, :eu, :gl, :en]
  config.default_locale = :es

  # Seguridad: restringir acceso al panel /system por IP
  # config.system_accesslist_ips = ["tu_ip"]  # descomentar si queremos restringir

  # Tamaño máximo de adjuntos en MB
  config.maximum_attachment_size = 10
  config.maximum_avatar_size = 5

  # Número de reportes antes de ocultar contenido
  # Cuando los usuarios reportan contenido inapropiado (un comentario, una propuesta, etc.), Decidim lleva la cuenta. 
  # Con este valor en 3, cuando un mismo contenido recibe 3 reportes se oculta automáticamente de la vista pública
  # y queda pendiente de revisión por los moderadores en el panel de administración.
  # Es una protección automática contra spam o contenido ofensivo sin esperar a que un admin lo revise manualmente.
  config.max_reports_before_hiding = 3

  # Separador CSV para exportaciones
  config.default_csv_col_sep = ";"

  # Throttling (protección DoS)
  config.throttling_max_requests = 100
  config.throttling_period = 1.minute

  # Tiempo de acceso sin confirmar email
  # Cuando un usuario se registra, Decidim le envía un email de confirmación.
  # Esta opción le permite navegar y participar en la plataforma durante X días aunque aún no haya confirmado su email. 
  # Pasados esos X días sin confirmar, su acceso queda restringido hasta que lo confirme.
  # Lo pongo a 0
  config.unconfirmed_access_for = 0.days

  # Snippets HTML personalizados (desactivado por seguridad)
  config.enable_html_header_snippets = false

  # Seguimiento de enlaces en newsletters
  # Cuando se envie un newsletter desde Decidim, esta opción añade automáticamente parámetros UTM
  # a los enlaces del email:
  # https://decidim.forosocial.org/processes/acuerdo?utm_source=newsletter&utm_medium=email&utm_campaign=...
  # Esto permite saber cuántos usuarios llegaron a una página concreta desde un newsletter,
  # con herramienta de analítica web como Matomo o similar.
  # Sin herramienta analítica web, esta opción no aporta nada práctico pero tampoco hace daño.
  config.track_newsletter_links = true

  # Tiempo disponible para descarga de datos
  config.download_your_data_expiry_time = 7.days
  
  # Configuración de mapas con OpenStreetMap
  # Tiles: tile.openstreetmap.org (raster PNG, compatible con Leaflet)
  # Geocodificación: Nominatim (OSM)
  # Autocompletado de direcciones: Photon (Komoot)
  config.maps = {
    provider: :osm,
    dynamic: {
      provider: :osm,
      tile_layer: {
        url: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors',
        max_zoom: 19
      }
    },
    geocoding: {
      host: "nominatim.openstreetmap.org",
      use_https: true
    },
    autocomplete: {
      url: "https://photon.komoot.io/api/"
    }
  }
 end