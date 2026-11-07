# config/initializers/decidim_taxonomy_intersect_fix.rb
#
# Evita PG::AmbiguousColumn en listados con filtro multi-taxonomía.
# Decidim::Taxonomizable#with_any_taxonomies, cuando hay varios grupos,
# convierte la consulta en FROM (SELECT ... INTERSECT SELECT ...) AS
# decidim_proposals_proposals, lo que rompe los ORDER BY posteriores.
# Este parche lo reescribe como un subquery de ids (WHERE id IN (...)).
module WithAnyTaxonomiesAsSubquery
  def with_any_taxonomies(*args)
    result = super
    return result unless result.values[:from].present?

    where(id: result.select(:id))
  end
end

Rails.application.config.to_prepare do
  Decidim::Proposals::Proposal.singleton_class.prepend(WithAnyTaxonomiesAsSubquery)
end
