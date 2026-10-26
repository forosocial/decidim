# config/initializers/validar_pareja_pacto_conflicto.rb
# valida lo que se envía en el formulario (servidor)
# depende de: app/services/conflicto_mapper.rb

Rails.application.config.to_prepare do
  module ValidarParejaPactoConflicto
    def self.prepended(base)
      base.validates :taxonomies, presence: true, if: :componente_con_filtros_pacto_conflicto?
      base.validate :presencia_pacto_y_conflicto
      base.validate :pareja_pacto_conflicto_valida
    end

    private

    # Detección estructural compartida: ¿el componente tiene filtro Pacto + filtro de items profundos?
    def componente_con_filtros_pacto_conflicto?
      raices_pacto_conflicto.present?
    end

    def raices_pacto_conflicto
      @raices_pacto_conflicto ||= begin
        roots = nil
        if current_component
          filtros = Decidim::TaxonomyFilter.select { |f| f.components.where(id: current_component.id).exists? }
          normaliza = ->(h) { (h || {}).values.compact_blank.map { |v| v.to_s.strip.downcase } }
          pacto_filter = filtros.find { |f| normaliza.call(f.name).any? { |v| v.start_with?("pacto") } }
          conflicto_filter = (filtros - [pacto_filter]).find do |f|
            f_ids = f.filter_taxonomy_ids
            f_ids.present? && Decidim::Taxonomy.where(id: f_ids).where.not(parent_id: f.root_taxonomy_id).exists?
          end
          roots = [pacto_filter&.root_taxonomy, conflicto_filter&.root_taxonomy] if pacto_filter && conflicto_filter
        end
        roots
      end
    end

    # Obligatoriedad específica: al menos un Pacto Y al menos un Conflicto
    def presencia_pacto_y_conflicto
      raices = raices_pacto_conflicto
      return unless raices

      pacto_root, conflicto_root = raices
      items = Decidim::Taxonomy.where(id: Array(taxonomies).reject(&:blank?))
      pacto_ids = pacto_root.all_children.ids
      conf_ids = conflicto_root.all_children.ids
      pacto_ok = items.any? { |t| pacto_ids.include?(t.id) }
      conflicto_ok = items.any? { |t| conf_ids.include?(t.id) && t.parent_id != conflicto_root.id }
      errors.add(:taxonomies, :blank) unless pacto_ok && conflicto_ok
    end

    def pareja_pacto_conflicto_valida
      raices = raices_pacto_conflicto
      return unless raices

      pacto_root, conflicto_root = raices

      filtros = Decidim::TaxonomyFilter.select { |f| f.components.where(id: current_component.id).exists? }
      normaliza = ->(h) { (h || {}).values.compact_blank.map { |v| v.to_s.strip.downcase } }
      pacto_root = filtros.find { |f| normaliza.call(f.name).any? { |v| v.start_with?("pacto") } }&.root_taxonomy
      conflicto_root = filtros.find { |f| normaliza.call(f.name).any? { |v| v.start_with?("conflicto") } }&.root_taxonomy
      return unless pacto_root && conflicto_root

      ids = Array(taxonomies).reject(&:blank?).map(&:to_i)
      items = Decidim::Taxonomy.where(id: ids).includes(:parent)

      pacto_item = items.find { |t| pacto_root.all_children.ids.include?(t.id) }
      hijos = items.select { |t| t.parent_id != conflicto_root.id && conflicto_root.all_children.ids.include?(t.id) }
      return unless pacto_item && hijos.any?

      componente_conflictos = current_component.participatory_space.components
                                               .where(manifest_name: "proposals")
                                               .where("decidim_components.name->>'es' = ?", "Conflictos")
                                               .first
      return unless componente_conflictos

      valido = hijos.all? do |h|
        Decidim::Proposals::Proposal
          .where(decidim_component_id: componente_conflictos.id, decidim_proposals_proposal_state_id: nil)
          .joins(:taxonomies)
          .where(decidim_taxonomies: { id: [pacto_item.id, h.parent_id] })
          .group("decidim_proposals_proposals.id")
          .having("COUNT(DISTINCT decidim_taxonomies.id) = 2")
          .exists?
      end

      errors.add(:taxonomies, :invalid) unless valido
    end
  end

  Decidim::Proposals::ProposalForm.prepend(ValidarParejaPactoConflicto)
  Decidim::Proposals::Admin::ProposalForm.prepend(ValidarParejaPactoConflicto)
end
