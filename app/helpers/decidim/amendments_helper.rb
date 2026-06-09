# frozen_string_literal: true

module Decidim
  module AmendmentsHelper
    def amendments_form_fields_value(original_resource, attribute)
      return params[:amendment][:emendation_params][attribute] if params[:amendment].present?

      resource = send(original_resource)

      if attribute == :body
        present(resource).body(strip_tags: !current_organization.rich_text_editor_in_public_views).strip
      else
        present(resource).send(attribute)
      end
    end

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
end
