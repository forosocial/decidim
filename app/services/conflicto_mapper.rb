# app/services/conflicto_mapper.rb
# Construye las opciones del select (presentación) con la función self.mapeo
# usado para app/views/decidim/proposals/admin/proposals/_form.html.erb
# Tambien con las funciones self.componente_propuestas(componente_actual),
# self.preseleccion_para(propuesta) y self.raiz(item) devuelve los parámetros necesarios
# para construir el botón en las páginas de las proposals tipo "Conflictos"
# y enviar para enviar los valores de Pacto y Conflicto al formulario
# usado en:
#            app/views/decidim/proposals/proposals/show.html.erb
#            app/views/decidim/proposals/admin/proposals/_form.html.erb
#            config/initializers/validar_pareja_pacto_conflicto.rb

class ConflictoMapper
  ID_COMPONENTE_PACTOS = 1
  ID_COMPONENTE_CONFLICTOS = 2
  ID_COMPONENTE_PROPUESTAS = 3

  def self.id_componente_pactos
    ID_COMPONENTE_PACTOS
  end

  def self.id_componente_conflictos
    ID_COMPONENTE_CONFLICTOS
  end

  def self.id_componente_propuestas
    ID_COMPONENTE_PROPUESTAS
  end

  def self.componente_propuestas(componente_actual)
    componente_actual.participatory_space.components
                     .where(manifest_name: "proposals")
                     .where(decidim_components: { id: ID_COMPONENTE_PROPUESTAS })
                     .first
  end

  # A partir de una propuesta del componente Conflictos, devuelve
  # [pacto_item_id, hijo_item_id] para preseleccionar el formulario de Propuestas.
  # Devuelve nil si la propuesta no es un conflicto (p. ej., un Pacto) → el botón no se muestra.

  def self.preseleccion_para(propuesta)
    items = propuesta.taxonomies
    pacto_item = items.find { |t| raiz(t).name["es"].to_s.strip.downcase.start_with?("pacto") }
    item_conf = items.find { |t| raiz(t).name["es"].to_s.strip.downcase.start_with?("conflicto") }
    return nil unless pacto_item && item_conf

    raiz_conf = raiz(item_conf)
    # Si la propuesta lleva el item de nivel 1 ("Conflicto N"), usamos su hijo;
    # si ya llevase el hijo directamente, lo usamos tal cual
    hijo = item_conf.parent_id == raiz_conf.id ? item_conf.children.order(:weight).first : item_conf
    return nil unless hijo

    [pacto_item.id, hijo.id]
  end

  def self.preseleccion_pacto(pacto)
    item = pacto.taxonomies
    pacto_item = item.find { |t| raiz(t).name["es"].to_s.strip.downcase.start_with?("pacto") }
    pacto_item.id
  end

  def self.raiz(item)
    node = item
    node = node.parent while node&.parent
    node
  end

  def self.mapeo(pacto_root:, conflicto_root:, componente_actual:)
    componente_conflictos = componente_actual.participatory_space.components
                                             .where(manifest_name: "proposals")
                                             .where(decidim_components: { id: ID_COMPONENTE_CONFLICTOS })
                                             .first
    return {} unless componente_conflictos

    hijo_por_conflicto = conflicto_root.children.to_h do |conf|
      [conf.id, conf.children.order(:weight).first&.id]
    end

    # CLAVE: cualquier descendiente de la raíz Pacto, a cualquier nivel
    pacto_ids = pacto_root.all_children.ids

    mapping = Hash.new { |h, k| h[k] = [] }

    Decidim::Proposals::Proposal
      .where(decidim_component_id: componente_conflictos.id, decidim_proposals_proposal_state_id: nil)
      .where.not(published_at: nil)
      .includes(:taxonomies)
      .find_each do |conflicto|
        pacto_item = conflicto.taxonomies.find { |t| pacto_ids.include?(t.id) }
        item_conf = conflicto.taxonomies.find { |t| t.parent_id == conflicto_root.id }
        next unless pacto_item && item_conf

        hijo_id = hijo_por_conflicto[item_conf.id]
        next unless hijo_id

        texto = Decidim::TranslationsHelper.translated_attribute(conflicto.title)
        id_conf = conflicto.id
        texto = "#{texto} (#{id_conf})"
        mapping[pacto_item.id] << { id: hijo_id, text: texto }
      end

    mapping
  end

  # Item de Pacto (a cualquier nivel) que lleva una propuesta
  def self.pacto_item_de(propuesta)
    propuesta.taxonomies.find do |t|
      raiz(t)&.name&.dig("es").to_s.strip.downcase.start_with?("pacto")
    end
  end

  # Item del árbol de conflicto que lleva una propuesta
  def self.conflicto_item_de(propuesta)
    propuesta.taxonomies.find do |t|
      raiz(t)&.name&.dig("es").to_s.strip.downcase.start_with?("conflicto")
    end
  end

  # TODOS los items hijo ("Propuesta resolución conflicto N") de una propuesta
  def self.hijo_items_de(propuesta)
    propuesta.taxonomies.select do |t|
      r = raiz(t)
      r && t.parent_id != r.id && r.name["es"].to_s.strip.downcase.start_with?("conflicto")
    end
  end

  # Para una propuesta del componente Propuestas:
  # [{ item: <"Conflicto N">, hijo: <hijo>, texto: "<título descriptivo>", proposal: <Proposal|nil> }]
  def self.conflictos_de_propuesta(propuesta, componente_conflictos)
    pacto_item = pacto_item_de(propuesta)
    hijos = hijo_items_de(propuesta)
    return [] unless pacto_item && hijos.any?

    conf_items = hijos.map(&:parent).uniq
    candidatos = Decidim::Proposals::Proposal
                 .where(decidim_component_id: componente_conflictos.id, decidim_proposals_proposal_state_id: nil)
                 .includes(:taxonomies)

    conf_items.map do |item|
      hijo = hijos.find { |h| h.parent_id == item.id }
      proposal = candidatos.find { |p| (p.taxonomies.map(&:id) & [pacto_item.id, item.id]).length == 2 }
      texto = proposal ? (proposal.title[I18n.locale.to_s].presence || proposal.title["es"]) : item.name["es"]
      { item: item, hijo: hijo, texto: texto, proposal: proposal }
    end
  end

  # Nº de propuestas (componente Propuestas) con el mismo pacto y alguno de los mismos hijos
  def self.n_propuestas_relacionadas(propuesta, componente_propuestas)
    pacto_item = pacto_item_de(propuesta)
    hijo_ids = hijo_items_de(propuesta).map(&:id)
    return 0 unless pacto_item && hijo_ids.any?

    count_con_pacto_e_hijos(componente_propuestas, pacto_item.id, hijo_ids)
  end

  # Número de propuestas del componente Propuestas asociadas a un (pacto, conflicto) concreto
  def self.propuestas_para_conflicto(conflicto, componente_propuestas)
    pacto_item = pacto_item_de(conflicto)
    item_conf = conflicto_item_de(conflicto)
    return 0 unless pacto_item && item_conf

    hijo_ids = item_conf.children.ids
    return 0 if hijo_ids.empty?

    count_con_pacto_e_hijos(componente_propuestas, pacto_item.id, hijo_ids)
  end

  def self.count_con_pacto_e_hijos(componente_propuestas, pacto_item_id, hijo_ids)
    base = Decidim::Proposals::Proposal.published.not_hidden
                                       .where(decidim_component_id: componente_propuestas.id)
    base
      .where(id: Decidim::Proposals::Proposal.joins(:taxonomies).where("decidim_taxonomies.id = ?", pacto_item_id).select(:id))
      .where(id: Decidim::Proposals::Proposal.joins(:taxonomies).where("decidim_taxonomies.id IN (?)", hijo_ids).select(:id))
      .count
  end

  # Texto de fecha de un encuentro, sin hora: día único "18/10/2026"
  # o rango "17/10/2026 – 18/10/2026" si cruza de día
  # Se usa en app/cells/decidim/author/date.erb
  #      y en config/initializers/historial_fecha_encuentros.rb
  def self.fecha_encuentro(meeting)
    fmt = "%d/%m/%Y"
    if meeting.start_time.to_date == meeting.end_time.to_date
      I18n.l(meeting.start_time, format: fmt)
    else
      "#{I18n.l(meeting.start_time, format: fmt)} – #{I18n.l(meeting.end_time, format: fmt)}"
    end
  end
end
