# frozen_string_literal: true

# URL: /processes/:slug/arbol  (p.ej. /processes/acuerdoecosocial/arbol)
# Vive en el engine de procesos participativos, a nivel de espacio (no de
# componente). Se ejecuta antes de que la app dibuje rutas. Sin to_prepare:
# no duplica rutas en reloads de desarrollo.
Decidim::ParticipatoryProcesses::Engine.routes.append do
  get "processes/:slug/arbol", to: "arbol#show", as: :arbol
end
