# frozen_string_literal: true

# Envía un evento a Umami cuando se publica una enmienda en Decidim,
# para comparar participación entre los distintos componentes del
# proceso "Acuerdo Ecosocial" (Pactos, Conflictos, Propuestas).
#
# Se suscribe al evento de dominio oficial que expone Decidim::EventsManager
# para "decidim.events.amendments.amendment_created", publicado únicamente
# cuando la enmienda ha sido publicada con éxito (Decidim::Amendable::PublishDraft).
#
# El "resource" del evento es el recurso original enmendado (amendable),
# del que leemos dinámicamente el tipo de componente y su título.

Rails.application.config.to_prepare do
  Decidim::EventsManager.subscribe("decidim.events.amendments.amendment_created") do |_event_name, data|
    amendable = data[:resource]
    next unless amendable.respond_to?(:component)

    component = amendable.component
    next unless component

    tipo = component.name&.dig("es").presence || component.name&.values&.find(&:present?)
    next unless tipo

    titulo = amendable.try(:title)&.dig("es").presence || amendable.try(:title)&.values&.find(&:present?)

    UmamiEventJob.perform_later(
      "enmienda_creada",
      {
        tipo: tipo,
        enmienda_a: titulo,
        commentable_id: amendable.id
      },
      "/processes/acuerdoecosocial"
    )
  end
end