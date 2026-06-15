# Para ajustar la Content Security Policy, consulta la documentación de Decidim:
# https://docs.decidim.org/en/develop/customize/content_security_policy

Rails.application.config.content_security_policy do |policy|
  # Permitir tiles de OpenStreetMap para los mapas Leaflet
  policy.img_src(*policy.img_src, "https://tile.openstreetmap.org", "https://*.tile.openstreetmap.org")

  # Permitir conexiones a Nominatim (geocodificación) y Photon (autocompletado)
  policy.connect_src(*policy.connect_src, "https://nominatim.openstreetmap.org", "https://photon.komoot.io")
end