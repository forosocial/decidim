# frozen_string_literal: true

# config/initializers/verificar_agrupaciones.rb
#
# Fail fast en el boot (y en cada reload en dev) si la raiz o el filtro
# de agrupaciones no existen o estan mal configurados: mejor un deploy
# que falla que propuestas sin enlace de forma silenciosa.
#
# IMPORTANTE: este initializer debe cargar DESPUES de
# conflicto_mapper_agrupaciones_patch.rb (orden alfabetico:
# "conflicto..." < "verificar...") para que los metodos ya esten
# prepended cuando se ejecute el bloque.
Rails.application.config.to_prepare do
  raiz = ConflictoMapper.raiz_agrupaciones
  if raiz.nil?
    raise "[Agrupaciones] No existe la taxonomia raiz id " \
          "#{ConflictoMapper::RAIZ_AGRUPACIONES_ID} ('Agrupaciones'). Crealas antes en Settings -> Taxonomies."
  end

  filtro = ConflictoMapper.filtro_grupos
  if filtro.nil?
    raise "[Agrupaciones] No existe el filtro id #{ConflictoMapper::FILTRO_GRUPOS_ID} ('Grupos')."
  end

  unless filtro.root_taxonomy_id == raiz.id
    raise "[Agrupaciones] El filtro #{filtro.id} ('Grupos') no apunta a la raiz " \
          "#{raiz.id} ('Agrupaciones'): root_taxonomy_id = #{filtro.root_taxonomy_id}."
  end

  # Sin componentes asignados no es error (la funcionalidad queda
  # preparada), pero conviene que el log lo deje escrito.
  Rails.logger.info("[Agrupaciones] Filtro #{filtro.id} asignado a componentes: " \
                    "#{filtro.components.map(&:id).join(', ').presence || '(ninguno)'}")
end
