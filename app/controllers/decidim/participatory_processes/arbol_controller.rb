# frozen_string_literal: true

module Decidim
  module ParticipatoryProcesses
    class ArbolController < Decidim::ParticipatoryProcesses::ApplicationController
      helper_method :arbol, :router_propuestas, :router_conflictos, :router_pactos,
                    :componente_propuestas, :current_participatory_space

      # Politica propia (sin enforce_permission_to): el arbol lo puede ver
      # CUALQUIER usuario (incluido anonimo) siempre que el proceso este
      # publicado y no sea privado. Los procesos privados o no publicados
      # se "filtran": 404, sin filtraciones de permisos.
      def show
        proceso = current_participatory_space
        return if proceso&.published? && !proceso.private_space?

        raise ActionController::RoutingError, "Not Found"
      end

      private

      # Este engine NO proporciona current_participatory_space en su
      # ApplicationController: cada controlador lo resuelve por su cuenta
      # (ver ParticipatoryProcessesController del propio Decidim). Lo
      # replicamos aqui, con ambito de organizacion (multi-tenant).
      def current_participatory_space
        return unless params[:slug]

        @current_participatory_space ||=
          Decidim::ParticipatoryProcess.where(organization: current_organization)
                                       .find_by(slug: params[:slug])
      end

      def arbol
        @arbol ||= ConflictoMapper.arbol(current_participatory_space)
      end

      # Los enlaces deben apuntar al componente que "posee" cada proposal.
      # La pagina vive a nivel de proceso, asi que el proxy hay que montarlo
      # por componente (misma leccion que ya aplicasteis con admin_proxy).
      def router_propuestas
        @router_propuestas ||= Decidim::EngineRouter.main_proxy(componente_propuestas)
      end

      def router_conflictos
        @router_conflictos ||= Decidim::EngineRouter.main_proxy(componente_conflictos)
      end

      def router_pactos
        @router_pactos ||= Decidim::EngineRouter.main_proxy(componente_pactos)
      end

      def componente_propuestas
        @componente_propuestas ||= ConflictoMapper.componente_propuestas(cualquier_componente)
      end

      def componente_conflictos
        @componente_conflictos ||= ConflictoMapper.componente_conflictos(current_participatory_space)
      end

      def componente_pactos
        @componente_pactos ||= ConflictoMapper.componente_pactos(current_participatory_space)
      end

      def cualquier_componente
        current_participatory_space.components.first
      end
    end
  end
end
