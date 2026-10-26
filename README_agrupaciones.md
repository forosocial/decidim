# Agrupaciones de propuestas (rama `agrupaciones_propuestas`)

Funcionalidad "Propuestas relacionadas" para el componente Propuestas,
basada en taxonomías:

- Raíz `Decidim::Taxonomy` **"Agrupaciones" (id 37)**: nivel 1 = grupos.
- Filtro `Decidim::TaxonomyFilter` **"Grupos" (id 6)**: asignar a cada
componente Propuestas que use la funcionalidad (settings del componente).
- Pertenecer a un grupo = llevar el item como taxonomía (tabla
`taxonomizations`). Las asignaciones SIEMPRE añaden/quitan solo la fila
del item del grupo: nunca se tocan items de Pacto/Conflicto, y no se
usa la acción masiva nativa "update taxonomies" (reemplaza el set
completo, ver handoff).

## Árbol de ficheros (rutas destino en la app)

```javascript
config/initializers/conflicto_mapper_agrupaciones_patch.rb   # métodos + IDs en ConflictoMapper (prepend)
config/initializers/verificar_agrupaciones.rb                # fail-fast en boot
config/initializers/rutas_agrupaciones.rb                    # CRUD en AdminEngine de proposals
app/forms/decidim/proposals/admin/agrupacion_form.rb         # form object (nombre traducido, proposal_ids)
app/controllers/decidim/proposals/admin/agrupaciones_controller.rb
app/views/decidim/proposals/admin/agrupaciones/index.html.erb
app/views/decidim/proposals/admin/agrupaciones/new.html.erb
app/views/decidim/proposals/admin/agrupaciones/edit.html.erb
app/views/decidim/proposals/admin/agrupaciones/_form.html.erb
app/views/decidim/proposals/admin/proposals/index.html.erb   # OVERRIDE upstream: botón de acceso en la cabecera (ver nota abajo)
config/locales/agrupaciones.es.yml                           # mergear con vuestro es.yml
config/locales/agrupaciones.en.yml                           # plantilla en (rellenar textos)
config/locales/agrupaciones.ca.yml                           # catalán
config/locales/agrupaciones.gl.yml                           # gallego
config/locales/agrupaciones.eu.yml                           # euskera
```

IMPORTANTE (0.31.4): en esta versión NO existe el menú
`:admin_proposals_menu` (el AdminEngine de proposals no registra ningún
menú; la navegación interna del componente son botones en la cabecera de
cada página — el propio botón de "Estados" es un `link_to` en el índice).
Por tanto:

- NO copiar `config/initializers/menu_agrupaciones.rb` (si se copió,
  borrarlo: registra en un menú que nadie renderiza).
- El acceso a "Agrupaciones de propuestas" va como botón en la cabecera
  del índice de propuestas, mediante el override
  `app/views/decidim/proposals/admin/proposals/index.html.erb` incluido
  (copia del original 0.31.4 + botón, marcado con comentario CUSTOM).
  Añadir su MD5 a `spec/lib/overrides_spec.rb` como hacéis con los demás
  overrides.

Además, dos TOQUES MANUALES en código existente (no se pueden generar
porque dependen de vuestros ficheros):

1. **Override `app/views/decidim/proposals/admin/proposals/_form.html.erb`** —
comprobar que la detección del filtro de conflicto es la condición
estructural (`items.where.not(parent_id: root)`), que sigue siendo
única con tres filtros (Pacto y Grupos tienen items hijos directos;
Conflicto no). Si la detección era "el otro filtro que no es pacto",
cambiarla por la estructural. El filtro "Grupos" se renderiza solo
con el form builder nativo y no necesita nada más.

NOTA sobre `config/initializers/validar_pareja_pacto_conflicto.rb`:
NO necesita modificación. El validador solo valida los items que son
descendientes de la raíz de conflictos (`hijos = items.select { ... conflicto_root.all_children.ids.include?(t.id) }`),
y los items de "Agrupaciones" (raíz 37) nunca lo son; además la búsqueda
de raíces por nombre ("pacto"/"conflicto") no se ve afectada por el
tercer filtro "Grupos". Verificarlo con el test del checklist (paso 7).

2. **Override público `app/views/decidim/proposals/proposals/show.html.erb`** —
añadir donde convenga (por ejemplo junto al botón de conflicto):

```erb
   <% ConflictoMapper.grupos_de(@proposal).each do |grupo_item| %>
     <%= link_to t("decidim.proposals.proposals.show.ver_relacionadas", grupo: grupo_item.name["es"]),
           Decidim::EngineRouter.main_proxy(current_component).proposals_path(
             filter: { with_any_taxonomies: { ConflictoMapper.raiz_agrupaciones.id => [grupo_item.id] } }) %>
   <% end %>
```

## Verificación en consola (tras copiar y reiniciar)

```ruby
ConflictoMapper.raiz_agrupaciones&.id   # => 37
ConflictoMapper.filtro_grupos&.id       # => 6
ConflictoMapper.filtro_grupos.root_taxonomy_id == 37  # => true
ConflictoMapper.filtro_grupos.components.pluck(:id)   # debe incluir el componente Propuestas

# items de pacto para el select (nivel 2)
ConflictoMapper.items_pacto.map { |i| [i.id, i.name["es"]] }

# opciones del multi-select
ConflictoMapper.propuestas_para_agrupar(Decidim::Component.find(3)).first(3)
```

Si la raíz o el filtro no existen, el initializer `verificar_agrupaciones.rb`
levanta error en el boot (fail fast, no silencioso).

Comprobación de rutas (el recurso se llama `grupos`; el inflector
singularizaría `agrupaciones` como `agrupacione`):

```ruby
Decidim::Proposals::AdminEngine.routes.routes.map(&:name).grep(/grupo/)
# => ["grupos", "new_grupo", "edit_grupo", "grupo"]
```

## Diagnóstico: el filtro "Grupos" no aparece en el formulario de propuesta ni en el índice público

Hay tres causas posibles, en este orden de probabilidad:

**A. El filtro no tiene items asignados.** Al crear un filtro en
Settings → Taxonomies → Filters, hay que marcar QUÉ items de la raíz
incluye (no basta con que la raíz tenga hijos). Comprobar:

```ruby
f = Decidim::TaxonomyFilter.find(6)
f.filter_items_count                 # si es 0, este es el problema (contador cacheado)
f.filter_items.map { |fi| fi.taxonomy_item.name["es"] }
# Solución: editar el filtro en el admin y marcar el/los items.
```

Decidim no muestra filtros vacíos ni en el sidebar público ni en los
formularios.

**B. La asignación filtro↔componente no se guardó.** Al marcar "Grupos"
en la configuración del componente hay que pulsar Update/Actualizar al
final del formulario. Comprobar:

```ruby
# (Component no tiene asociación directa consultable aquí; ir del filtro
# hacia los componentes — el filtro cachea components_count)
Decidim::TaxonomyFilter.find(6).components_count   # => 1
Decidim::TaxonomyFilter.find(6).components.pluck(:id) # => [3] (¿incluye el del componente Propuestas?)
```

**C. El formulario admin de propuesta está overrideado.** El override
`app/views/decidim/proposals/admin/proposals/_form.html.erb` reemplazó
el render nativo de filtros por los selects custom de pacto/conflicto,
así que el select de "Grupos" NO aparecerá ahí aunque todo lo demás esté
bien (es comportamiento esperado, no un fallo). La asignación a grupos
se hace desde la página "Agrupaciones de propuestas" de todos modos.

Si se quiere el select también en el formulario de propuesta, hay que
re-añadir en el override el loop nativo que renderiza los filtros NO
custom. En 0.31.4 el original (gem decidim-proposals,
`app/views/decidim/proposals/admin/proposals/_form.html.erb`) renderiza
TODOS los filtros así:

```erb
<% if @form.taxonomy_filters&.any? %>
  <% @form.taxonomy_filters.each do |filter| %>
    <div class="row column">
      <%= filter_taxonomy_items_select_field form, :taxonomies, filter %>
    </div>
  <% end %>
<% end %>
```

En el override, ese loop fue sustituido por los selects custom de
pacto/conflicto. Para que "Grupos" aparezca, re-añadir el loop
EXCLUYENDO los dos filtros custom (usar los mismos nombres de variable
que el override ya emplee para pacto_filter y conflicto_filter):

```erb
<%# Render nativo de los filtros NO custom (p.ej. "Grupos") %>
<% no_custom = (@form.taxonomy_filters || []).reject { |f| [pacto_filter, conflicto_filter].include?(f) } %>
<% no_custom.each do |filter| %>
  <div class="row column">
    <%= filter_taxonomy_items_select_field form, :taxonomies, filter %>
  </div>
<% end %>
```

Colocarlo dentro del `form`, en el hueco que ocupaba el loop nativo
(p.ej. antes de los attachments). No requiere cambios de controlador:
`@form.taxonomy_filters` ya viene poblado en el form object.


## Checklist de puesta en marcha

1. Crear rama `agrupaciones_propuestas` desde `proposal_form` (o `main` si
ya está mergeada).
2. Copiar los ficheros a sus rutas.
3. Aplicar los dos toques manuales (revisar `_form` admin + añadir el
bloque de enlaces en el `show` público; el validador NO se toca).
4. Asignar el filtro "Grupos" al componente Propuestas en los procesos
correspondientes (settings del componente → taxonomías).
5. Reiniciar y verificar consola (arriba).
6. Admin → componente Propuestas → en el listado de propuestas, botón
"Agrupaciones de propuestas" (cabecera, junto a "Estados"): crear un
grupo, comprobar que la propuesta muestra el enlace público y que el
filtro aparece en la barra lateral del índice.
7. Editar y guardar desde el admin nativo una propuesta que lleva grupo:
debe seguir siendo válida (comprueba que el validador de pares ignora
los items de "Agrupaciones"). Comprobar también el caso mixto: propuesta
con pacto + conflicto + grupo, donde el par (pacto, conflicto) es
válido sigue validando.

## Notas

- El nombre del grupo se guarda como hash i18n completo
(`form.translated` genera una pestaña por locale disponible), así que
añadir idiomas después no requiere migración de datos.
- Los literales de interfaz van en `config/locales/agrupaciones.{es,en}.yml`.
- `pacto_item_id` en el formulario es solo filtro de UI (repoblado tras
errores de validación); no se persiste.
- En la edición de un grupo, las propuestas miembros siempre son visibles
en el multi-select aunque no coincidan con el filtro de pacto elegido
(evita perder miembros de otros pactos al guardar).