# frozen_string_literal: true

# config/initializers/conflicto_mapper_agrupaciones_patch.rb
#
# Metodos de "agrupaciones de propuestas" anadidos a ConflictoMapper por
# prepend sobre la singleton class: NO hace falta editar
# app/services/conflicto_mapper.rb. Mismo patron que
# conflicto_mapper_arbol_patch.rb.
#
# Modelo: la raiz "Agrupaciones" (37) tiene en nivel 1 los grupos;
# pertenecer a un grupo = llevar ese item como taxonomia (tabla
# taxonomizations; ANYADIR, nunca reemplazar). El filtro "Grupos" (6)
# debe estar asignado a cada componente Propuestas que use la
# funcionalidad (settings del componente).
#
# Los IDs se fijan una sola vez al crear raiz + filtro y no cambian al
# renombrar. Si se hiciera un rebuild de base de datos, actualizar aqui.

module ConflictoMapperAgrupaciones
  RAIZ_AGRUPACIONES_ID = 37
  FILTRO_GRUPOS_ID = 6
  RAIZ_PACTO_ID = 1 # raiz "Pacto"; sus nietos (nivel 2) son los pactos concretos
  LIMITE_NOMBRE_GRUPO = 40

  def raiz_agrupaciones
    Decidim::Taxonomy.find_by(id: RAIZ_AGRUPACIONES_ID)
  end

  def filtro_grupos
    Decidim::TaxonomyFilter.find_by(id: FILTRO_GRUPOS_ID)
  end

  # Pactos concretos (nivel 2) para el select de filtrado del formulario
  def items_pacto
    Decidim::Taxonomy.where(parent_id: Decidim::Taxonomy.where(parent_id: RAIZ_PACTO_ID).select(:id))
                     .order(:weight)
  end

  def grupos_agrupaciones
    raiz = raiz_agrupaciones
    return Decidim::Taxonomy.none if raiz.nil?

    Decidim::Taxonomy.where(parent_id: raiz.id).order(:weight)
  end

  # Items de "Agrupaciones" que lleva una propuesta
  def grupos_de(propuesta)
    propuesta.taxonomies.select { |t| t.parent_id == RAIZ_AGRUPACIONES_ID }
  end

  # Relacion de propuestas del componente que llevan ese item de grupo.
  # Mismo patron que propuestas_de_conflicto: joins en string SQL.
  def propuestas_de_grupo(grupo_item, componente_propuestas)
    base = Decidim::Proposals::Proposal.where(component: componente_propuestas)
    base.where(id: base.joins(:taxonomies)
                       .where("decidim_taxonomies.id = ?", grupo_item.id))
        .order(:id)
  end

  # Opciones para el multi-select del formulario admin:
  # [{id:, title:, pacto_id:}] con pacto_id = ConflictoMapper.pacto_item_de
  def propuestas_para_agrupar(componente_propuestas)
    Decidim::Proposals::Proposal.where(component: componente_propuestas)
                                .includes(:taxonomies).order(:id).map do |p|
      { id: p.id, title: p.title["es"].to_s, pacto_id: pacto_item_de(p)&.id }
    end
  end
end

# No referenciar la clase de app/ en el nivel superior del initializer
# (Zeitwerk aun no ha resuelto en el boot). to_prepare lo aplaza y el
# prepend es idempotente. Misma justificacion que en el patch del arbol.
#
# IMPORTANTE: el prepend a la singleton class hace que los METODOS se
# resuelvan (ConflictoMapper.raiz_agrupaciones), pero las CONSTANTES del
# modulo prepended NO se resuelven como ConflictoMapper::X (la busqueda
# de constantes va por ConflictoMapper.ancestors, no por la singleton
# class). Por eso se copian aqui con const_set; sin el guard, los
# reloads de to_prepare re-definirian la constante.
Rails.application.config.to_prepare do
  ConflictoMapper.singleton_class.prepend(ConflictoMapperAgrupaciones)

  {
    RAIZ_AGRUPACIONES_ID: ConflictoMapperAgrupaciones::RAIZ_AGRUPACIONES_ID,
    FILTRO_GRUPOS_ID: ConflictoMapperAgrupaciones::FILTRO_GRUPOS_ID,
    RAIZ_PACTO_ID: ConflictoMapperAgrupaciones::RAIZ_PACTO_ID,
    LIMITE_NOMBRE_GRUPO: ConflictoMapperAgrupaciones::LIMITE_NOMBRE_GRUPO
  }.each do |nombre, valor|
    ConflictoMapper.const_set(nombre, valor) unless ConflictoMapper.const_defined?(nombre, false)
  end
end
