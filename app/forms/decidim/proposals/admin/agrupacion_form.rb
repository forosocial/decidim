# frozen_string_literal: true

# app/forms/decidim/proposals/admin/agrupacion_form.rb

module Decidim
  module Proposals
    module Admin
      # Formulario de alta/edicion de un grupo de propuestas ("agrupacion").
      #
      # - nombre: hash traducido completo (se edita con form.translated:
      #   una pestana por locale disponible). Se guarda tal cual en
      #   Decidim::Taxonomy#name, asi que anadir idiomas despues no
      #   requiere migracion de datos.
      # - proposal_ids: propuestas miembros del grupo.
      # - pacto_item_id: SOLO filtro de la UI (se repuebla tras un error
      #   de validacion para no perder el filtro elegido); no se persiste.
      class AgrupacionForm < Decidim::Form
        mimic :agrupacion

        # translatable_attribute (no "attribute :nombre, Hash"): define el
        # hash :nombre Y los accesores por locale (:nombre_es, :nombre_ca...)
        # que form.translated espera; los setters fusionan cada locale en
        # el hash.
        translatable_attribute :nombre, String
        attribute :proposal_ids, [Integer]
        attribute :pacto_item_id, Integer

        validates :nombre, translatable_presence: true
        validates :proposal_ids, presence: true
        validate :nombre_dentro_del_limite

        private

        # El error se anota en el atributo concreto (nombre_es, nombre_ca...),
        # que es el que renderiza form.translated: asi Decidim pinta el campo
        # en rojo y muestra el mensaje inline. Si se anota en :nombre (el
        # hash) solo se ve el flash generico.
        def nombre_dentro_del_limite
          (nombre || {}).each do |locale, valor|
            next if valor.blank?

            next unless valor.length > ConflictoMapper::LIMITE_NOMBRE_GRUPO

            errors.add(:"nombre_#{locale}", :nombre_too_long,
                       count: ConflictoMapper::LIMITE_NOMBRE_GRUPO,
                       actual: valor.length)
          end
        end
      end
    end
  end
end
