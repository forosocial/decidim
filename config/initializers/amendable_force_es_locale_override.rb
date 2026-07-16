# config/initializers/amendable_force_es_locale_override.rb
# frozen_string_literal: true
#
# Override: fuerza el idioma 'es' para el title/body de las enmiendas,
# independientemente del idioma de interfaz del usuario que crea, edita
# o acepta la enmienda.
#
# Motivo: Decidim::Amendable::{CreateDraft,UpdateDraft,Accept} usan
# I18n.locale (el idioma de interfaz activo) como clave del hash de
# title/body, en vez del idioma real en el que está escrito el contenido.
# Además, la asignación original SUSTITUYE el hash completo en vez de
# fusionarlo, perdiendo las traducciones a otros idiomas ya existentes.
#
# Como actualmente todas las "proposals" de Foro Social están redactadas
# únicamente en castellano y no hay capacidad de traducción a los otros
# idiomas configurados (ca, eu, gl, en), forzamos 'es' como idioma de
# las enmiendas en los tres pasos de su ciclo de vida, usando merge para
# no destruir ninguna traducción que pudiera existir.
#
# Cuando haya traducciones reales disponibles para algún idioma, revisar
# si este override sigue siendo necesario o hay que sustituirlo por una
# detección más fina (idioma real del contenido en vez de 'es' fijo).
#
# Fichero upstream vigilado en overrides_spec.rb:
#   decidim-core · app/commands/decidim/amendable/create_draft.rb
#   decidim-core · app/commands/decidim/amendable/update_draft.rb
#   decidim-core · app/commands/decidim/amendable/accept.rb

Rails.application.config.after_initialize do
  FORCED_AMENDMENT_LOCALE = "es"

  module AmendableForceEsLocaleOnCreateDraft
    private

    def create_emendation!
      PaperTrail.request(enabled: false) do
        @emendation = Decidim.traceability.perform_action!(
          :create,
          amendable.class,
          current_user,
          visibility: "public-only"
        ) do
          emendation = amendable.class.new(form.emendation_params)
		  emendation.title = { FORCED_AMENDMENT_LOCALE => form.emendation_params.with_indifferent_access[:title] }
		  emendation.body = { FORCED_AMENDMENT_LOCALE => form.emendation_params.with_indifferent_access[:body] }
          emendation.component = amendable.component
          emendation.taxonomies = amendable.taxonomies if amendable.respond_to?(:taxonomies)
          emendation.add_author(current_user)
          emendation.save!
          emendation
        end
      end
    end
  end

  module AmendableForceEsLocaleOnUpdateDraft
    private

    def update_draft
		PaperTrail.request(enabled: false) do
			previous_title = emendation.title.is_a?(Hash) ? emendation.title : {}
			previous_body = emendation.body.is_a?(Hash) ? emendation.body : {}

			emendation.assign_attributes(form.emendation_params)
			emendation.title = previous_title.merge(
			FORCED_AMENDMENT_LOCALE => form.emendation_params.with_indifferent_access[:title]
			)
			emendation.body = previous_body.merge(
			FORCED_AMENDMENT_LOCALE => form.emendation_params.with_indifferent_access[:body]
			)
			emendation.add_author(current_user)
			emendation.save!
		end
	end
  end

  module AmendableForceEsLocaleOnAccept
    private

    def update_amendable!
		@amendable = Decidim.traceability.perform_action!(
			:update,
			@amendable,
			@amender,
			visibility: "public-only"
		) do
			previous_title = @amendable.title.is_a?(Hash) ? @amendable.title : {}
			previous_body = @amendable.body.is_a?(Hash) ? @amendable.body : {}

			@amendable.assign_attributes(form.emendation_params)
			@amendable.title = previous_title.merge(
			FORCED_AMENDMENT_LOCALE => form.emendation_params.with_indifferent_access[:title]
			)
			@amendable.body = previous_body.merge(
			FORCED_AMENDMENT_LOCALE => form.emendation_params.with_indifferent_access[:body]
			)
			@amendable.save!
			@amendable
		end
		@amendable.add_coauthor(@amender) if @amendable.is_a?(Decidim::Coauthorable)
	end
  end

  Decidim::Amendable::CreateDraft.prepend(AmendableForceEsLocaleOnCreateDraft)
  Decidim::Amendable::UpdateDraft.prepend(AmendableForceEsLocaleOnUpdateDraft)
  Decidim::Amendable::Accept.prepend(AmendableForceEsLocaleOnAccept)
end