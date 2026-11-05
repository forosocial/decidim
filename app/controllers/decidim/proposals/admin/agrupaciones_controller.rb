# frozen_string_literal: true

module Decidim
  module Proposals
    module Admin
      # CRUD de agrupaciones de propuestas (grupos = items nivel 1 de la
      # raiz "Agrupaciones"; pertenencia = fila en taxonomizations).
      #
      # Hereda de ApplicationController del admin de proposals: mismo
      # layout, mismo current_component y mismo contexto de permisos que
      # el resto de pantallas del componente.
      class AgrupacionesController < Decidim::Proposals::Admin::ApplicationController
        helper_method :grupos, :grupo, :conteos, :items_pacto,
                      :propuestas_opciones, :router_agrupaciones, :router_publico

        before_action only: [:new, :create, :edit, :update, :destroy] do
          enforce_permission_to :manage, :component
        end

        def index; end

        def new
          @form = form(AgrupacionForm).instance
        end

        def create
          @form = form(AgrupacionForm).from_params(params)
          if @form.invalid?
            flash.now[:alert] = t(".error")
            render :new, status: :unprocessable_entity
            return
          end

          item = nil
          ActiveRecord::Base.transaction do
            item = Decidim::Taxonomy.create!(
              name: @form.nombre,
              parent: ConflictoMapper.raiz_agrupaciones,
              organization: current_organization,
              weight: (ConflictoMapper.grupos_agrupaciones.maximum(:weight) || -1) + 1
            )
            # Sin TaxonomyFilterItem el grupo NO aparece en el filtro
            # publico ni en el select nativo de la propuesta.
            Decidim::TaxonomyFilterItem.create!(
              taxonomy_filter: ConflictoMapper.filtro_grupos,
              taxonomy_item: item,
              weight: (ConflictoMapper.filtro_grupos.filter_items.maximum(:weight) || -1) + 1
            )
            sincronizar_miembros(item, @form.proposal_ids)
          end

          flash[:notice] = t(".exito", nombre: item.name["es"])
          redirect_to router_agrupaciones.grupos_path
        end

        def edit
          # Asignacion explicita setter a setter: la mass-assignment del
          # constructor no es fiable con los atributos traducidos
          # (nombre_es, nombre_ca...) generados por translatable_attribute.
          @form = form(AgrupacionForm).instance
          (grupo.name || {}).each { |locale, valor| @form.public_send("nombre_#{locale}=", valor) }
          @form.proposal_ids = ids_miembros(grupo)
        end

        def update
          @form = form(AgrupacionForm).from_params(params)
          if @form.invalid?
            flash.now[:alert] = t(".error")
            render :edit, status: :unprocessable_entity
            return
          end

          ActiveRecord::Base.transaction do
            grupo.update!(name: @form.nombre)
            sincronizar_miembros(grupo, @form.proposal_ids)
          end

          flash[:notice] = t(".exito", nombre: grupo.name["es"])
          redirect_to router_agrupaciones.grupos_path
        end

        def destroy
          nombre = grupo.name["es"]
          ActiveRecord::Base.transaction do
            Decidim::Taxonomization.where(taxonomy: grupo).destroy_all
            Decidim::TaxonomyFilterItem.where(taxonomy_item: grupo).destroy_all
            grupo.destroy!
          end

          flash[:notice] = t(".exito", nombre: nombre)
          redirect_to router_agrupaciones.grupos_path
        end

        private

        def grupo
          @grupo ||= ConflictoMapper.grupos_agrupaciones.find(params[:id])
        end

        def grupos
          @grupos ||= ConflictoMapper.grupos_agrupaciones
        end

        # Conteo de miembros por grupo, en una sola query (evita N+1).
        # OJO: la FK de taxonomizations es "taxonomy_id" (sin prefijo).
        def conteos
          @conteos ||= Decidim::Taxonomization.where(taxonomy: grupos,
                                                     taxonomizable_type: "Decidim::Proposals::Proposal")
                                              .group(:taxonomy_id)
                                              .count
        end

        def items_pacto
          @items_pacto ||= ConflictoMapper.items_pacto
        end

        def componente_propuestas
          @componente_propuestas ||= ConflictoMapper.componente_propuestas(current_component).tap do |c|
            raise "ConflictoMapper: no hay componente 'Propuestas' en este espacio" if c.nil?
          end
        end

        # Opciones del multi-select con flag :miembro para que la vista
        # JS mantenga siempre visibles a los miembros actuales (aunque
        # no coincidan con el filtro de pacto elegido). :otro_grupo lleva
        # el nombre de la agrupacion actual de la propuesta SOLO si no es
        # el grupo que se esta editando (la vista lo muestra tras el
        # titulo para avisar de que seleccionarla la cambia de grupo).
        def propuestas_opciones
          @propuestas_opciones ||= begin
            miembros = @grupo ? ids_miembros(@grupo) : []
            ConflictoMapper.propuestas_para_agrupar(componente_propuestas).map do |o|
              otro = o[:grupo_id].present? && o[:grupo_id] != @grupo&.id ? o[:grupo_nombre] : nil
              o.merge(miembro: miembros.include?(o[:id]), otro_grupo: otro)
            end
          end
        end

        def router_agrupaciones
          @router_agrupaciones ||= Decidim::EngineRouter.admin_proxy(current_component)
        end

        def router_publico
          @router_publico ||= Decidim::EngineRouter.main_proxy(componente_propuestas)
        end

        # Miembros por joins (mismo patron que propuestas_de_conflicto):
        # no depende del string del tipo polimorfico taxonomizable_type.
        def ids_miembros(item)
          Decidim::Proposals::Proposal.where(component: componente_propuestas)
                                      .joins(:taxonomies)
                                      .where(decidim_taxonomies: { id: item.id })
                                      .pluck(:id)
        end

        # Deja el grupo exactamente con ids_validos como miembros:
        # - ids se re-validan contra el componente Propuestas (un POST
        #   con ids de otro componente no tiene efecto);
        # - solo se crean/destruyen filas taxonomizations de items de la
        #   raiz "Agrupaciones": los items de Pacto/Conflicto nunca se tocan;
        # - semantica de "mover": una propuesta solo puede pertenecer a UN
        #   grupo, asi que al añadirla aqui se le quitan las pertenencias a
        #   otros grupos (si no, al elegir una propuesta de otro grupo
        #   quedaria en los dos).
        def sincronizar_miembros(item, ids)
          validos = Decidim::Proposals::Proposal.where(component: componente_propuestas)
                                                .where(id: Array(ids))
                                                .pluck(:id)

          # 1) Quitar del grupo a los que ya no estan en la seleccion
          Decidim::Taxonomization.where(taxonomy: item,
                                        taxonomizable_type: "Decidim::Proposals::Proposal")
                                 .where.not(taxonomizable_id: validos)
                                 .destroy_all

          # 2) Mover: quitar pertenencias a OTROS grupos de los miembros
          otros_ids = ConflictoMapper.grupos_agrupaciones.where.not(id: item.id).pluck(:id)
          if otros_ids.any?
            Decidim::Taxonomization.where(taxonomy_id: otros_ids,
                                          taxonomizable_type: "Decidim::Proposals::Proposal",
                                          taxonomizable_id: validos)
                                   .destroy_all
          end

          # 3) Añadir al grupo las pertenencias que faltan
          Decidim::Proposals::Proposal.where(component: componente_propuestas, id: validos).find_each do |p|
            p.taxonomies << item unless p.taxonomies.exists?(item.id)
          end
        end
      end
    end
  end
end
