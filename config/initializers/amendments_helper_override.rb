# config/initializers/amendments_helper_override.rb
# frozen_string_literal: true

# Override de Decidim::AmendmentsHelper
# Motivo: amendments_form_field_for recibe el body como Hash translatable
# {"es" => "<p>...</p>"} en lugar del string HTML de la traducción actual,
# lo que impide que TipTap inicialice el editor correctamente.
# El override fuerza form.object[:body] al string traducido antes de que
# hidden_field lo lea.

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
      form.object[:body] = options[:value]
      options.delete(:value)
      text_editor_for(form, :body, options)
    end
  end
end