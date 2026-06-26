# spec/lib/overrides_spec.rb
# frozen_string_literal: true
# Basado en https://github.com/Som-Energia/decidim-som-energia-app/blob/main/spec/lib/overrides_spec.rb
require "rails_helper"
require "digest"
# Spec de seguridad para overrides locales de ficheros de Decidim.
#
# Cada entrada mapea una ruta relativa dentro del gem a su MD5 en el momento
# en que se escribió el override. Si Decidim actualiza ese fichero, el checksum
# cambia y el spec falla, avisándonos de que hay que revisar el override.
#
# Flujo al actualizar Decidim:
#   1. El spec falla indicando qué fichero cambió y su nuevo checksum.
#   2. Revisa el diff upstream para ese fichero.
#   3. Actualiza el override local si es necesario.
#   4. Sustituye el checksum en este spec por el nuevo valor.
#
# Para añadir un nuevo override:
#   1. Añadir una entrada en el hash del gem correspondiente.
#   2. Obtén el checksum con:
#        bundle exec ruby -e "require 'digest'; puts Digest::MD5.hexdigest(
#          File.read(File.join(Gem::Specification.find_by_name('GEM').gem_dir, 'RUTA'))
#        )"
OVERRIDES = {
  "decidim-core" => {
    # Override: config/initializers/amendments_helper_override.rb
    # Motivo: con rich_text_editor_in_public_views: false, text_editor_for
    # renderiza un textarea plano en el formulario de enmienda en lugar de
    # montar TipTap. El override llama a form.editor directamente y parchea
    # decidim_amendments_form_field_for (alias que crea Awesome del original
    # de core) para que el fix tenga efecto cuando Awesome no tiene custom
    # fields configurados.
    "app/helpers/decidim/amendments_helper.rb" => "db42be326ff225c422e2c126d784b477"
  },
  "decidim-decidim_awesome" => {
    # Override: config/initializers/amendments_helper_override.rb
    # Si Awesome cambia su AmendmentsHelperOverride hay que revisar si
    # el alias decidim_amendments_form_field_for sigue siendo el punto
    # correcto donde aplicar el fix.
    "app/helpers/concerns/decidim/decidim_awesome/amendments_helper_override.rb" => "875761b6e8e7d7b45bbdd339609f4fd9"
  },
  "decidim-proposals" => {
    # Override: config/initializers/proposals_default_states_override.rb
    # Motivo: ProposalsController#default_states marca por defecto en el
    # filtro todos los estados del componente excepto "rejected" (incluye
    # "evaluating"). El override usa Module#prepend para excluir también
    # "evaluating" del filtro por defecto, pero solo en los componentes
    # "Pactos" y "Conflictos" (Propuestas mantiene el comportamiento
    # original de Decidim vía `super`). Si Decidim cambia la lógica o
    # firma de default_states, revisar el prepend.
    "app/controllers/decidim/proposals/proposals_controller.rb" => "92bf9b32eb4968b6ad71c1711e4750d2"
  }
}.freeze
RSpec.describe "Decidim overrides" do
  OVERRIDES.each do |gem_name, files|
    context "gem: #{gem_name}" do
      let(:gem_dir) { Gem::Specification.find_by_name(gem_name).gem_dir }
      files.each do |relative_path, expected_checksum|
        describe relative_path do
          let(:full_path) { File.join(gem_dir, relative_path) }
          let(:current_checksum) { Digest::MD5.hexdigest(File.read(full_path)) }
          it "has not changed since the override was written" do
            expect(current_checksum).to eq(expected_checksum), <<~MSG
              El fichero upstream ha cambiado en #{gem_name}:
                #{full_path}
              Revisa si el override local sigue siendo necesario y correcto,
              actualízalo si procede, y reemplaza el checksum en este spec.
              Nuevo checksum: #{current_checksum}
            MSG
          end
        end
      end
    end
  end
end