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
#   Ejemplo:
#        bundle exec ruby -e "require 'digest'; puts Digest::MD5.hexdigest(
#          File.read(File.join(Gem::Specification.find_by_name('decidim-core').gem_dir, 'app/cells/decidim/activity_cell.rb'))
#        )"

# Tras añadir una nueva entrada a este spec es necesario probarlo
# RAILS_ENV=test bundle exec rspec spec/lib/overrides_spec.rb

#########
#     USO
#########
# Tras realizar una actualización de Decidim ejecutar:
#      bundle exec rspec spec/lib/overrides_spec.rb
#

OVERRIDES = {
  "decidim-core" => {
    # Override: config/initializers/amendments_helper_override.rb
    # Motivo: con rich_text_editor_in_public_views: false, text_editor_for
    # renderiza un textarea plano en el formulario de enmienda en lugar de
    # montar TipTap. El override llama a form.editor directamente y parchea
    # decidim_amendments_form_field_for (alias que crea Awesome del original
    # de core) para que el fix tenga efecto cuando Awesome no tiene custom
    # fields configurados.
    "app/helpers/decidim/amendments_helper.rb" => "db42be326ff225c422e2c126d784b477",

    # Override: config/initializers/amendable_force_es_locale_override.rb
    # Motivo: Decidim::Amendable::{CreateDraft,UpdateDraft,Accept} usan
    # I18n.locale (el idioma de interfaz activo) como clave del hash de
    # title/body, en vez del idioma real en el que está escrito el contenido.
    # Además, la asignación original SUSTITUYE el hash completo en vez de
    # fusionarlo, perdiendo las traducciones a otros idiomas ya existentes.
    # Como actualmente todas las "proposals" de Foro Social están redactadas
    # únicamente en castellano y no hay capacidad de traducción a los otros
    # idiomas configurados (ca, eu, gl, en), forzamos 'es' como idioma de
    # las enmiendas en los tres pasos de su ciclo de vida, usando merge para
    # no destruir ninguna traducción que pudiera existir.
    # Cuando haya traducciones reales disponibles para algún idioma, revisar
    # si este override sigue siendo necesario o hay que sustituirlo por una
    # detección más fina (idioma real del contenido en vez de 'es' fijo).
    #
    "app/commands/decidim/amendable/create_draft.rb" => "6dab877c9ad517bce2474d45cb68b339",
    "app/commands/decidim/amendable/update_draft.rb" => "b1aa9bbc241174f4d3e0b64acb376b50",
    "app/commands/decidim/amendable/accept.rb" => "8b72f8a77140573a89724b33db4840b4",

    # Override: config/initializers/activity_cell_cache_override.rb
    # Motivo: cache_hash no incluye ningún componente temporal, por lo que
    # el string "Hace X minutos/horas" queda congelado en caché desde el
    # primer render. El override añade un bucket horario para forzar
    # expiración cada 60 minutos como máximo.
    # ActivityCell hereda cache_expiry_time global (24h) pero renderiza
    # tiempo relativo ("Hace X minutos") que queda congelado en caché. El override
    # añade un bucket horario a cache_hash para forzar expiración cada 60 minutos.
    # El problema es que en los listados de actividad no aparece correctamente el tiempo
    # que hace desde la ejecución de la actividad.
    # Para que surta efecto tras la implementación de este override ha sido necesario
    # Limpiar caché de Redis para que los registros se rerenderizen ya
    # RAILS_ENV=production bundle exec rails runner "Rails.cache.clear"
    #
    "app/cells/decidim/activity_cell.rb" => "e2345598669f6312f17ee964950a83bc",

    # Override de traducción: config/locales/gl.yml
    # corrige un error en las cadenas oficiales de
    # Decidim para decidim.amendments.emendation.announcement (gl).
    #
    # Motivo: las cuatro cadenas (accepted, evaluating, rejected, withdrawn)
    # usan las interpolaciones %{amendable_link} y %{announcement_date}, pero
    # el código (Decidim::Amendable::AnnouncementCell) construye el hash de
    # interpolación con las claves %{proposal_link} y %{date}. Al no coincidir
    # los nombres, I18n lanza "missing interpolation argument" y rompe la
    # vista de la propuesta para cualquier usuaria con idioma gallego activo
    # al ver una enmienda (evaluando, aceptada, rechazada o retirada).
    "config/locales/gl.yml" => "dfce4a7294eb152b1e620c73e23d57fd",

    # Override de traducción: config/locales/eu.yml
    # corrige un error en la cadena "rejected" de
    # decidim.amendments.emendation.announcement (eu).
    #
    # Motivo: igual que el override de gl.yml (ver ese fichero para más
    # detalle) pero acotado solo a "rejected", que es la única de las cuatro
    # cadenas mal escrita en euskera. Usa %{amendable_link}/%{announcement_date}
    # en vez de %{proposal_link}/%{date}, provocando "missing interpolation
    # argument" al ver una enmienda rechazada con idioma euskera activo.
    "config/locales/eu.yml" => "447b0c63fb8e9ccb756aeba7e8ccc282"
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
    #
    # Tambien:
    # Override: app/services/conflicto_mapper.rb
    # Revisar ambos en caso de cambio.

    "app/controllers/decidim/proposals/proposals_controller.rb" => "92bf9b32eb4968b6ad71c1711e4750d2",
    
    # Override: app/views/decidim/proposals/admin/proposals/_form.html.erb
    # Motivo: Cambiar el formulario de ceación de las proposas Propuestas para que
    # en lugar de mostrar "Conflicto N" muestre el título del Conflicto del Pacto
    # en cuestión.
    # Los otros elementos (mapper: app/services/conflicto_mapper.rb e initializer:
    # config/initializers/validar_pareja_pacto_conflicto.rb , son ficheros nuevos
    # que no tienen contrapartida upstream, así que no tienen entrada que vigilar.
    # Sin embargo, el initializer hace prepend sobre Decidim::Proposals::Admin::ProposalForm
    # y asume que existe el atributo taxonomies y el contexto current_component.
    # Si en una actualización Decidim renombra esa clase o cambia el manejo de
    # taxonomías en el formulario, la validación podría romperse silenciosamente.
    # En el caso de que cambie, no significa que el initializer deje de funcionar,
    # pero es la señal de revisar que taxonomies y current_component siguen existiendo.
    "app/views/decidim/proposals/admin/proposals/_form.html.erb" => "3c6d2675fa774c888150dc8da494fee0",
    "app/forms/decidim/proposals/admin/proposal_form.rb" => "c222792947e0bac2cd4869adb5ce13bb",
    
    # Override: app/views/decidim/proposals/proposals/show.html.erb
    # Motivo: Creación de un botón "Crear propuesta para este conflicto" visible 
    # sólo para administradores y que abre en una nueva pestaña para incluir una nueva
    # Propuesta en la que ya incluye la selección adecuada de Pacto y Conflicto.
    "app/views/decidim/proposals/proposals/show.html.erb" => "e2c0adf5c283f7396d93207e1b7ab740"
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
