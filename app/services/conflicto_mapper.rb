# app/services/conflicto_mapper.rb
# construye las opciones del select (presentación)

class ConflictoMapper
  NOMBRE_COMPONENTE_CONFLICTOS = "Conflictos".freeze

  def self.mapeo(pacto_root:, conflicto_root:, componente_actual:)
    componente_conflictos = componente_actual.participatory_space.components
      .where(manifest_name: "proposals")
      .where("decidim_components.name->>'es' = ?", NOMBRE_COMPONENTE_CONFLICTOS)
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