# config/initializers/preseleccion_taxonomias_propuestas.rb

# Uso un parámetro propio (pre_taxonomies) para no interferir con el parámetro
# real del formulario (proposal[taxonomies][]). Al asignar @form.taxonomies,
# el partial ya calcula pacto_selected/conflicto_selected a partir de ahí y el JS
# preselecciona ambos desplegables.

Rails.application.config.to_prepare do
  module PreseleccionTaxonomiasEnNew
    def new
      super
      if params[:pre_taxonomies].present?
        @form.taxonomies = Array(params[:pre_taxonomies]).reject(&:blank?).map(&:to_i)
      end
    end
  end

  Decidim::Proposals::Admin::ProposalsController.prepend(PreseleccionTaxonomiasEnNew)
end