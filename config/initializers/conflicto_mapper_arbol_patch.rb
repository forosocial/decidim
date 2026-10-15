# frozen_string_literal: true

# config/initializers/conflicto_mapper_arbol_patch.rb

# Metodos del arbol anadidos a ConflictoMapper por prepend sobre la singleton
# class: NO hace falta editar app/services/conflicto_mapper.rb.
# (Alternativa: copiar los metodos de ConflictoMapperArbol dentro del mapper
# y borrar este initializer.)
#
# Supuestos del modelo (ver handoff):
#  - Un conflicto lleva exactamente un item Pacto y un item nivel-1 de la
#    raiz de conflictos (los items "Conflicto N" tienen exactamente 1 hijo).
#  - Los conflictos no llevan items de la raiz "Circulos".

module ConflictoMapperArbol
  # Devuelve el arbol completo:
  #   [[pacto_item, { pacto_propuestas:, conflictos: [nodo, ...] }], ...]
  #
  # - Ramas (pactos): filtradas segun ArbolConfig::ESTADOS_PACTOS. Una rama
  #   desaparece si ninguna proposal del componente "Pactos" con ese item
  #   coincide con el filtro.
  # - Conflictos: filtrados segun ArbolConfig::ESTADOS_CONFLICTOS.
  # - Hojas (propuestas): filtradas segun ArbolConfig::ESTADOS_PROPUESTAS.
  # - pacto_propuestas se devuelve SIN filtrar, para que las etiquetas de
  #   estado sirvan de debug aunque la rama este filtrada.

  def arbol(espacio)
    comp_pactos = componente_del_espacio(espacio, "Pactos")
    comp_conflictos = componente_del_espacio(espacio, "Conflictos")
    comp_propuestas = componente_del_espacio(espacio, "Propuestas")

    conflictos = filtrar_estados(
      Decidim::Proposals::Proposal.where(component: comp_conflictos)
                                  .where.not(published_at: nil)
                                  .includes(taxonomies: [:parent, :children]),
      ArbolConfig::ESTADOS_CONFLICTOS
    )

    nodos = conflictos.filter_map do |conflicto|
      items = conflicto.taxonomies.to_a
      conflicto_item = items.detect { |t| t.children.any? }
      next unless conflicto_item

      pacto_item = items.detect do |t|
        t.id != conflicto_item.id && raiz(t)&.id != raiz(conflicto_item)&.id
      end
      next unless pacto_item

      {
        pacto_item: pacto_item,
        conflicto_item: conflicto_item,
        conflicto: conflicto,
        propuestas: propuestas_de_conflicto(conflicto, comp_propuestas,
                                            estados: ArbolConfig::ESTADOS_PROPUESTAS)
      }
    end

    ramas = nodos.group_by { |n| n[:pacto_item] }

    ramas.filter_map do |pacto_item, ns|
      todas_pp = propuestas_de_pacto(pacto_item, comp_pactos, estados: [:todas])
      visibles = propuestas_de_pacto(pacto_item, comp_pactos, estados: ArbolConfig::ESTADOS_PACTOS)

      sin_filtro_pactos = ArbolConfig::ESTADOS_PACTOS.map(&:to_sym).include?(:todas)
      next if !sin_filtro_pactos && visibles.none?

      [pacto_item,
       { pacto_propuestas: todas_pp,
         pacto_propuestas_filtradas: visibles,
         conflictos: ns.sort_by { |n| n[:conflicto_item].weight } }]
    end.sort_by { |pacto_item, _| pacto_item.weight }
  end

  # Version "records" del contador existente: MISMA condicion por par
  # (pacto, conflicto) - siempre con string SQL - pero devolviendo la
  # relacion para listar. `estados:` filtra por estado (default: todas).
  def propuestas_de_conflicto(conflicto, componente_propuestas, estados: [:todas])
    items = conflicto.taxonomies.to_a
    conflicto_item = items.detect { |t| t.children.any? }
    pacto_item = items.detect do |t|
      t.id != conflicto_item&.id && raiz(t)&.id != raiz(conflicto_item)&.id
    end
    return Decidim::Proposals::Proposal.none if pacto_item.blank? || conflicto_item.blank?

    base = Decidim::Proposals::Proposal.where(component: componente_propuestas)
    con_pacto = base.where(id: base.joins(:taxonomies)
                                   .where("decidim_taxonomies.id = ?", pacto_item.id))
    con_hijo = con_pacto.where(id: con_pacto.joins(:taxonomies)
                                   .where("decidim_taxonomies.id IN (?)",
                                          conflicto_item.children.select(:id)))
    filtrar_estados(con_hijo.order(:id), estados)
  end

  # El contador existente delega en la version records: una sola fuente de
  # verdad para la condicion por par. Misma firma publica que hasta ahora.
  def propuestas_para_conflicto(conflicto, componente_propuestas)
    propuestas_de_conflicto(conflicto, componente_propuestas).count
  end

  # proposals del componente "Pactos" que llevan ese item de pacto
  def propuestas_de_pacto(pacto_item, componente_pactos, estados: [:todas])
    rel = Decidim::Proposals::Proposal.where(component: componente_pactos)
                                      .where.not(published_at: nil)
                                      .joins(:taxonomies)
                                      .where("decidim_taxonomies.id = ?", pacto_item.id)
    filtrar_estados(rel.order(:id), estados)
  end

  def componente_del_espacio(espacio, nombre)
    espacio.components.detect { |c| c.name["es"].to_s == nombre } ||
      espacio.components.detect { |c| c.name["en"].to_s == nombre }
  end

  def componente_conflictos(espacio)
    componente_del_espacio(espacio, "Conflictos")
  end

  def componente_pactos(espacio)
    componente_del_espacio(espacio, "Pactos")
  end

  private

  # estados: simbolos de ArbolConfig. :todas o vacio = sin filtrar.
  #
  # NOTA (Decidim 0.31): las propuestas NO tienen columna `state`; el estado
  # vive en `decidim_proposals_proposal_states` (columna `token`, por
  # componente) y la proposal apunta con `decidim_proposals_proposal_state_id`.
  #   - :sin_respuesta -> FK IS NULL (estado no asignado)
  #   - :aceptada/:rechazada/:evaluando -> JOIN por token
  def filtrar_estados(relacion, estados)
    simbolos = Array(estados).map(&:to_sym)
    return relacion if simbolos.empty? || simbolos.include?(:todas)

    tokens = simbolos.map { |s| ArbolConfig::MAPEO_ESTADOS.fetch(s) }.compact
    con_nulos = simbolos.include?(:sin_respuesta)

    rel = relacion.joins("LEFT JOIN decidim_proposals_proposal_states AS dps " \
                         "ON dps.id = decidim_proposals_proposals.decidim_proposals_proposal_state_id")
    conds = []
    conds << "dps.token IN (?)" if tokens.any?
    conds << "decidim_proposals_proposals.decidim_proposals_proposal_state_id IS NULL" if con_nulos

    sql = conds.join(" OR ")
    tokens.any? ? rel.where(sql, tokens) : rel.where(sql)
  end
end

# No referenciar la clase de app/ en el nivel superior del initializer:
# durante el boot la autoload de Zeitwerk aun no resuelve. to_prepare lo
# aplaza a despues del boot (y a cada reload en dev). Prepend es idempotente.
Rails.application.config.to_prepare do
  ConflictoMapper.singleton_class.prepend(ConflictoMapperArbol)
end
