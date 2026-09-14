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
      .includes(:taxonomies)
      .find_each do |conflicto|
        pacto_item = conflicto.taxonomies.find { |t| pacto_ids.include?(t.id) }
        item_conf = conflicto.taxonomies.find { |t| t.parent_id == conflicto_root.id }
        next unless pacto_item && item_conf

        hijo_id = hijo_por_conflicto[item_conf.id]
        next unless hijo_id

        texto = conflicto.title[I18n.locale.to_s].presence || conflicto.title["es"]
        mapping[pacto_item.id] << { id: hijo_id, text: texto }
      end

    mapping
  end
end
