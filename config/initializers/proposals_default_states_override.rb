# frozen_string_literal: true
#
# OVERRIDE: Decidim::Proposals::ProposalsController#default_states
#
# Por defecto, Decidim marca como "activos" en el filtro todos los estados
# configurados en el componente (incluido "evaluating") excepto "rejected".
# El código original (decidim-proposals 0.31.4):
#
#   def default_states
#     [
#       Decidim::Proposals::ProposalState.where(component: current_component).pluck(:token).map(&:to_s),
#       %w(state_not_published)
#     ].flatten - ["rejected"]
#   end
# 
# En el caso de que quisiesemos sobreescribir todos los filtros
# aplicados a todos los componentes presentes y futuros excluyendo "evaluating"
# tendríamos que dejarlo así:
# def default_states
#  return super unless target_component?   # Propuestas y cualquier otro → comportamiento original íntegro
#  super - %w(evaluating)                  # Pactos y Conflictos → original menos "evaluating"
# end
#
# El override actual excluye también "evaluating" del filtro por defecto,
# pero SOLO en los componentes "Pactos" y "Conflictos". El componente
# "Propuestas" mantiene el comportamiento original de Decidim (vía `super`).
#
# La verificación de que el fichero original no ha cambiado se hace en
# spec/lib/overrides_spec.rb, siguiendo el patrón centralizado
# de overrides del proyecto.

module ForoSocial
  module Overrides
    module ProposalsControllerDefaultStates
      # Nombres (en castellano) de los componentes de Propuestas sobre los
      # que queremos excluir "evaluating" del filtro por defecto.
      TARGET_COMPONENT_NAMES = %w(Pactos Conflictos).freeze

      def default_states
        return super unless target_component?

        super - %w(evaluating)
      end

      private

      def target_component?
        component_name = translated_attribute(current_component.name).to_s
        TARGET_COMPONENT_NAMES.include?(component_name)
      end
    end
  end
end

Rails.application.config.to_prepare do
  Decidim::Proposals::ProposalsController.prepend(
    ForoSocial::Overrides::ProposalsControllerDefaultStates
  )
end