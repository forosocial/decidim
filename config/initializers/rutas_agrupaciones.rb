# frozen_string_literal: true

# config/initializers/rutas_agrupaciones.rb
#
# Anade el CRUD de agrupaciones al engine admin de proposals. Al vivir
# DENTRO del AdminEngine, hereda el scope del mount point
# (.../components/:component_id/...), igual que las rutas nativas
# (proposals, proposal_states, ...). El guard evita el doble registro
# en reloads.
#
# NOTA: el recurso se llama "grupos" (no "agrupaciones") porque el
# inflector de Rails singulariza "agrupaciones" como "agrupacione"
# (reglas en ingles: solo quita la ultima "s"), generando helpers del
# tipo "new_agrupacione_path". "grupos" -> "grupo" singulariza bien.
# El controlador sigue siendo AgrupacionesController.
unless Decidim::Proposals::AdminEngine.routes.routes.any? { |r| r.name == "grupos" }
  Decidim::Proposals::AdminEngine.routes.append do
    resources :grupos, controller: "agrupaciones", except: [:show]
  end
end
