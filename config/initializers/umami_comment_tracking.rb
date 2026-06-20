# frozen_string_literal: true

# Envía un evento a Umami cuando se crea un comentario en Decidim,
# para comparar participación entre Pactos, Conflictos y Propuestas.
#
# Se suscribe al evento de dominio oficial que expone Decidim::Comments
# (Decidim::Comments::CommentCreation), que solo se publica cuando el
# comentario se ha guardado con éxito en base de datos — evitando así
# falsos positivos por errores de validación o de red en el cliente.
#
# Mapeo de componentes (Decidim::Component#id) del proceso "Acuerdo Ecosocial":
#   1 -> Pactos
#   2 -> Conflictos
#   3 -> Propuestas

Rails.application.config.to_prepare do
  Decidim::Comments::CommentCreation.subscribe do |data|
    comment = Decidim::Comments::Comment.find_by(id: data[:comment_id])
    next unless comment

    commentable = comment.root_commentable
    next unless commentable.respond_to?(:component)

    component_id = commentable.component&.id
    tipo = case component_id
           when 1 then "Pacto"
           when 2 then "Conflicto"
           when 3 then "Propuesta"
           end
    next unless tipo

    UmamiEventJob.perform_later(
      "comentario_creado",
      { tipo: tipo, commentable_id: commentable.id },
      "/processes/acuerdoecosocial"
    )
  end
end