# config/initializers/amendments_helper_override.rb
# frozen_string_literal: true

# Override de Decidim::AmendmentsHelper
# Motivo: amendments_form_field_for recibe el body como Hash translatable
# {"es" => "<p>...</p>"} en lugar del string HTML de la traducción actual,
# lo que impide que TipTap inicialice el editor correctamente.
# El override fuerza form.object[:body] al string traducido antes de que
# hidden_field lo lea.

Rails.application.config.to_prepare do
  Decidim::AmendmentsHelper.class_eval do
    def amendments_form_field_for(attribute, form, original_resource)
      options = {
        label: amendments_form_fields_label(attribute),
        value: amendments_form_fields_value(original_resource, attribute)
      }

      case attribute
      when :title
        form.text_field(:title, options)
      when :body
        # El body se almacena como Hash translatable. Forzamos strip_tags: false
        # porque el editor TipTap necesita el HTML para inicializarse,
        # independientemente de rich_text_editor_in_public_views.
        body_value = present(send(original_resource)).body(strip_tags: false).strip
        text_editor_for(form, :body, options.merge(value: body_value))
      end
    end
  end
end