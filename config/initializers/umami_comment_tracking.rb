# frozen_string_literal: true

# Envía un evento a Umami cuando se crea un comentario en Decidim,
# para comparar participación entre los distintos componentes del
# proceso "Acuerdo Ecosocial" (Pactos, Conflictos, Propuestas).
#
# Se suscribe al evento de dominio oficial que expone Decidim::Comments
# (Decidim::Comments::CommentCreation), que solo se publica cuando el
# comentario se ha guardado con éxito en base de datos — evitando así
# falsos positivos por errores de validación o de red en el cliente.
#
# El nombre del componente (tipo) y el título del recurso comentado
# (comentario_a) se leen dinámicamente, sin mapeo manual por ID, para
# que funcione automáticamente si se añaden nuevos componentes.
Rails.application.config.to_prepare do
  Decidim::Comments::CommentCreation.subscribe do |data|
    comment = Decidim::Comments::Comment.find_by(id: data[:comment_id])
    next unless comment

    commentable = comment.root_commentable
    next unless commentable.respond_to?(:component)

    component = commentable.component
    next unless component

    tipo = component.name&.dig("es") || component.name&.values&.first
    next unless tipo

    titulo = commentable.try(:title)&.dig("es") || commentable.try(:title)&.values&.first

    UmamiEventJob.perform_later(
      "comentario_creado",
      {
        tipo: tipo,
        comentario_a: titulo,
        commentable_id: commentable.id
      },
      "/processes/acuerdoecosocial"
    )
  end
end