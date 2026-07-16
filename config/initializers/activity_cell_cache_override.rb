# config/initializers/activity_cell_cache_override.rb
# frozen_string_literal: true

# Fix: ActivityCell cachea el string de tiempo relativo ("Hace X minutos")
# usando únicamente model.cache_key_with_version, que nunca cambia para
# los registros de ActionLog (son inmutables tras crearse). El resultado es
# que el string queda congelado en caché desde el primer render, produciendo
# tiempos incorrectos en /last_activities (ej: "Hace 8 minutos" cuando en
# realidad han pasado 3 días).
#
# Fix: añadir un bucket horario al cache_hash para que la caché expire
# como máximo cada 60 minutos.
#
# Fichero upstream vigilado en overrides_spec.rb:
#   decidim-core · app/cells/decidim/activity_cell.rb · e2345598669f6312f17ee964950a83bc
#
# Reportado issue: https://github.com/decidim/decidim/issues/17257 

Rails.application.config.after_initialize do
  Decidim::ActivityCell.prepend(Module.new do
    def cache_hash
      # Bucket de 1 hora: cambia cada 3600 segundos, forzando expiración
      # periódica del string de tiempo relativo renderizado en show.erb.
      super + [Decidim.cache_key_separator, (Time.current.to_i / 3600).to_s].join
    end
  end)
end
