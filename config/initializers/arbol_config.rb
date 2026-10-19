# frozen_string_literal: true

# ============================================================================
# Configuracion del arbol Pacto -> Conflicto -> Propuestas
# DEBUG: editad las listas y reiniciad el servidor (es un initializer).
#
# ESTADOS_* (independientes por componente):
#   :todas          -> sin filtrar por estado
#   :sin_respuesta  -> sin estado asignado (FK proposal_state IS NULL)
#   :aceptada       -> token 'accepted'
#   :rechazada      -> token 'rejected'
#   :evaluando      -> token 'evaluating'
# Pueden ponerse varios, p.ej. %i[aceptada evaluando]
#
# En PACTOS el mismo filtro decide DOS cosas: que ramas aparecen y que
# botones de estado se pintan en la linea del pacto.
#
# ORDEN_ESTADOS: orden de los botones de estado dentro de cada linea de
# nodo (consensuada = sin estado asignado). Tokens desconocidos al final.
#
# NOTA (Decidim 0.31): no existe la columna proposals.state; el estado vive
# en ProposalState#token. Ver conflicto_mapper_arbol_patch.rb.
# ============================================================================
module ArbolConfig
  # proposals del componente "Pactos": filtran que RAMAS aparecen y que
  # BOTONES se pintan en la linea del pacto
  ESTADOS_PACTOS = [:sin_respuesta, :evaluando].freeze

  # proposals del componente "Conflictos": el SEGUNDO nivel del arbol
  ESTADOS_CONFLICTOS = [:todas].freeze

  # proposals del componente "Propuestas": las HOJAS del arbol
  ESTADOS_PROPUESTAS = [:todas].freeze

  # orden canonico de los botones de estado en cada linea
  ORDEN_ESTADOS = %w(consensuada accepted evaluating rejected not_answered withdrawn).freeze

  MAPEO_ESTADOS = {
    aceptada: "accepted",
    rechazada: "rejected",
    evaluando: "evaluating",
    sin_respuesta: nil
  }.freeze
end
