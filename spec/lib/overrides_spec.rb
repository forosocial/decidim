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

    # Override: config/initializers/amendments_controller_accept_without_merge.rb
    # Motivo: se añade una acción alternativa "aceptar sin fusionar" para el
    # caso de enmiendas en conflicto sobre el mismo texto (dos coautores
    # enmendando la misma propuesta): permite marcar una enmienda como
    # aceptada (state, notificaciones) sin ejecutar update_amendable!, para
    # que el administrador incorpore el cambio a mano sin sobrescribir lo ya
    # fusionado por otra enmienda aceptada previamente. El override usa
    # Module#prepend sobre la acción #accept, distinguiendo por el parámetro
    # skip_merge. Si Decidim cambia la firma o lógica de esta acción
    # (por ejemplo, el nombre del form o el comando invocado), hay que
    # revisar el prepend y el nuevo comando AcceptWithoutMerge.
    "app/controllers/decidim/amendments_controller.rb" => "4cc807fab4dab816bbf67730178a2e36",

    # Override: app/views/decidim/amendments/review.html.erb (copia local,
    # no prepend — Rails prioriza la vista de la app sobre la del gem)
    # Motivo: se añade un segundo botón "Aceptar sin fusionar (incorporación
    # manual)" en el formulario de revisión de la enmienda, que envía
    # skip_merge=1 al mismo accept_amend_path. Si Decidim actualiza esta
    # vista (nuevos campos, cambios de estilos, etc.), la copia local se
    # desincroniza silenciosamente y hay que revisar/rehacer el override.
    "app/views/decidim/amendments/review.html.erb" => "0a653271f8c3b5daeea210c0f597c970"
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
