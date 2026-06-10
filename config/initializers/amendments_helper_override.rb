# config/initializers/amendments_helper_override.rb
# frozen_string_literal: true
#
# Override de Decidim::AmendmentsHelper
#
# Causa raíz: con rich_text_editor_in_public_views: false en la organización,
# text_editor_for cae en form.text_area en lugar de form.editor (TipTap),
# mostrando el HTML del body como texto plano en el formulario de enmienda.
# El formulario de enmienda siempre necesita TipTap independientemente de
# esa configuración, ya que es un formulario de edición, no una vista pública.
#
# Complejidad adicional: decidim-decidim_awesome sobreescribe
# amendments_form_field_for y aliasa el original de core como
# decidim_amendments_form_field_for. Nuestro override parchea ese alias
# para que tenga efecto cuando Awesome no tiene custom fields configurados.
#
# Se usa after_initialize (en lugar de to_prepare) para garantizar que el
# patch se aplica después del include de Awesome en su engine.

Rails.application.config.after_initialize do
  Decidim::AmendmentsHelper.class_eval do
    def decidim_amendments_form_field_for(attribute, form, original_resource)
      options = {
        label: amendments_form_fields_label(attribute)
      }

      case attribute
      when :title
        form.text_field(:title, options.merge(
          value: amendments_form_fields_value(original_resource, attribute)
        ))
      when :body
        # Forzamos form.editor directamente porque text_editor_for cae en
        # text_area cuando rich_text_editor_in_public_views es false.
        # El formulario de enmienda siempre necesita TipTap independientemente
        # de esa configuración.
        options[:lines] ||= 25
        options[:context] ||= "participant"
        options[:value] = present(send(original_resource)).body(strip_tags: false).strip
        form.editor(:body, options)
      end
    end
  end
end