# frozen_string_literal: true

module Decidim
  module ParticipatoryProcesses
    module ArbolHelper
      # Boton admin (mismo flujo que el del show de conflicto: preseleccion +
      # pre_taxonomies + nueva pestana). Se renderiza solo para admins.
      def boton_nueva_propuesta_conflicto(conflicto)
        return unless current_user&.admin?

        ids = ConflictoMapper.preseleccion_para(conflicto)
        return if ids.blank?

        link_to t("decidim.participatory_processes.arbol.boton_nueva_propuesta"),
                Decidim::EngineRouter.admin_proxy(componente_propuestas)
                                     .new_proposal_path(pre_taxonomies: ids),
                class: "button button__sm button__secondary",
                target: "_blank", rel: "noopener"
      end

      # true cuando ESTADOS_PACTOS filtra EXACTAMENTE por :sin_respuesta:
      # en ese modo no se pinta la etiqueta "consensuada" (redundante: todo
      # lo visible lo es) y en su lugar la vista muestra el body de las
      # proposals consensuadas, traducido al idioma actual.
      # true cuando el filtro de estados de un nivel es EXACTAMENTE
      # [:sin_respuesta]: en ese modo no se pintan botones "consensuada"
      # (todos los visibles lo son) y el enlace pasa al titulo del nodo.
      def solo_consensuadas?(estados)
        Array(estados).map(&:to_sym) == %i[sin_respuesta]
      end

      # Orden canonico de los botones de estado en la linea de un nodo,
      # segun ArbolConfig::ORDEN_ESTADOS. Los tokens desconocidos van al
      # final (por id, para mantener determinismo).
      def ordenar_por_estado(records)
        orden = ArbolConfig::ORDEN_ESTADOS
        records.sort_by do |r|
          clave = r.state.presence || "consensuada"
          [orden.index(clave) || orden.size, r.id]
        end
      end

      # Etiquetas de estado con las clases de Decidim (label success/alert/warning).
      # proposal.state es un METODO (0.31): token, "not_answered" o nil.
      CLASES_ESTADO = {
        "accepted" => "label success",
        "rejected" => "label alert",
        "evaluating" => "label warning"
      }.freeze

      # nil (sin estado asignado) se etiqueta como "consensuada". OJO:
      # proposal.state devuelve nil tambien si el estado esta asignado pero
      # aun no publicado (ver Proposal#state en Decidim 0.31).
      # NOTA: las clases CSS van en `class:`, NUNCA en `style:`.
      def etiqueta_estado(propuesta)
        estado = propuesta.state
        clave = estado.presence || "consensuada"
        clase = CLASES_ESTADO[estado] || "label success"
        content_tag(:span, t("decidim.participatory_processes.arbol.estados.#{clave}", default: clave.to_s.humanize),
                    class: "#{clase} arbol-estado")
      end

      # Desplegable acumulativo de body (checkbox hack CSS puro, sin JS):
      # un icono en el nodo que muestra/oculta el body de la proposal
      # "vigente" (la sin estado, preferente) bajo el titulo. `sufijo` debe
      # ser unico por ubicacion en la pagina (la misma proposal puede ser
      # target en varios nodos: multi-conflicto).
      def desplegable_body(propuesta, sufijo:)
        return if propuesta.blank?

        id_dom = "arbol-body-#{sufijo}-#{propuesta.id}"
        cuerpo = decidim_sanitize(translated_attribute(propuesta.body))
        safe_join([
          tag.input(type: "checkbox", id: id_dom, class: "arbol-toggle-state"),
          tag.label("▸", for: id_dom, class: "arbol-toggle",
                    title: t("decidim.participatory_processes.arbol.desplegar", default: "Mostrar u ocultar el contenido")),
          content_tag(:div, cuerpo, class: "arbol-cuerpo")
        ])
      end
    end
  end
end
