# Arbol Pacto -> Conflicto -> Propuestas

URL: `/processes/acuerdoecosocial/arbol` (a nivel de proceso participativo).
Probado en Decidim 0.31.4 (estado de propuestas via `ProposalState#token`).

## Instalacion
1. Copiar cada archivo a su ruta dentro de la app (las rutas del zip ya son
   las rutas de la app).
2. Reiniciar el servidor (hay initializers). Con Spring: `bin/spring stop`.

No se toca ningun archivo del gem: **no hay que anadir checksums** a
`spec/lib/overrides_spec.rb`.

## Archivos
- `config/initializers/arbol_config.rb` — DEBUG: estados por componente y
  orden de botones.
- `config/initializers/arbol_route.rb` — ruta `/processes/:slug/arbol`.
- `config/initializers/conflicto_mapper_arbol_patch.rb` — metodos nuevos del
  mapper via prepend (arbol, propuestas_de_conflicto, propuestas_de_pacto,
  filtrar_estados, lookups por nombre a nivel espacio). El contador existente
  `propuestas_para_conflicto` delega en la version "records" (mismo SQL).
- `config/locales/decidim_arbol.yml` — es/ca/gl/eu/en.
- `app/controllers/decidim/participatory_processes/arbol_controller.rb`
- `app/helpers/decidim/participatory_processes/arbol_helper.rb`
- `app/views/decidim/participatory_processes/arbol/show.html.erb`

## Configuracion (arbol_config.rb)
- `ESTADOS_PACTOS`: filtra QUE RAMAS aparecen y QUE BOTONES se pintan en la
  linea del pacto (un solo filtro para ambas cosas).
- `ESTADOS_CONFLICTOS` / `ESTADOS_PROPUESTAS`: segundo nivel y hojas.
- Valores: `:todas`, `:sin_respuesta`, `:aceptada`, `:rechazada`, `:evaluando`
  (combinables). `ORDEN_ESTADOS`: orden canonico de los botones de estado en
  cada linea (consensuada = sin estado asignado; tokens desconocidos al final).
- Las etiquetas de estado se pintan SIEMPRE con el estado real (las
  `pacto_propuestas_filtradas` son las que pasan el filtro; el contador de
  hojas es la union deduplicada por id de todos los records del conflicto).

## Renderizado
- Agrupacion por padre: los pactos se agrupan bajo su item padre, con
  "Pactos transversales" primero y "Pactos tematicos" despues (id de padre
  DESCENDENTE — si el id real de "transversales" fuera menor que el de
  "tematicos", invertir el sort en la vista). Pactos por id ascendente
  dentro de cada rama. Las ramas padre son etiquetas sin enlace (clase
  `arbol-node--grupo`). Ver ids con `Decidim::Taxonomy.where(parent_id: 1)`.
- Un nodo por item "Conflicto N" (`group_by` por `conflicto_item.id`): los
  records del mismo conflicto (original, enmiendas, duplicados con el mismo
  par pacto/conflicto) aparecen en UNA linea, con un boton de estado por
  record, cada uno enlazando a su proposal.
- Hojas: una linea por titulo (`group_by` por `title["es"]`); records con el
  mismo titulo agrupan sus botones. OJO: dos propuestas distintas con titulo
  exactamente igual se fusionarian visualmente.
- Desplegable de body: cada nodo (pacto/conflicto/propuesta) lleva un icono
  (checkbox hack CSS puro, sin JS; acumulativo y accesible) que muestra/oculta
  el body de la proposal vigente (la sin estado, preferente). Helper
  `desplegable_body(propuesta, sufijo:)` — el sufijo garantiza ids unicos por
  ubicacion (una proposal multi-conflicto puede ser target en varios nodos).
  NOTA: los input checkbox se ocultan con selector cualificado
  (`.arbol-tree input.arbol-toggle-state`): Decidim estiliza
  `input[type=checkbox]` con mas especificidad que una clase suelta.
- Alternador global (arriba de todo): despliega/encoge TODOS los bodies con
  CSS puro via `:has()` (Firefox 121+, Chromium 105+; sin JS). Mientras esta
  activo, los desplegables individuales quedan anulados (se fuerza visible).
- Regla de enlace/titulo: modo "solo consensuada" (filtro exactamente
  `[:sin_respuesta]`) -> sin botones y titulo enlazado; resto de modos ->
  titulo en texto plano y un boton por record con su enlace (sin redundancia
  entre titulo y botones).
- CSS del arbol embebido en la vista (conectores, niveles de color,
  `grid-column: 1 / -1`).

## Verificacion en consola
    a = ConflictoMapper.arbol(Decidim::ParticipatoryProcess.find_by(slug: "acuerdoecosocial"))
    a.each do |pacto, rama|
      puts "#{pacto.name["es"]} (#{rama[:conflictos].size} conflictos)"
      rama[:conflictos].each { |n| puts "  - #{n[:conflicto].title["es"]} -> #{n[:propuestas].size} propuestas" }
    end

## LECCIONES (no repetir peleas)
1. **Decidim 0.31: no existe la columna `proposals.state`.** El estado vive
   en `decidim_proposals_proposal_states.token` (por componente, estados
   personalizables) y la proposal apunta con
   `decidim_proposals_proposal_state_id`. Filtrar por SQL: LEFT JOIN por
   token / `FK IS NULL` para sin estado. `proposal.state` es un METODO:
   devuelve el token, "not_answered" o nil (nil tambien si el estado esta
   asignado pero NO publicado — ver `Proposal#state`). NO confundir con
   `decidim_amendments.state`, que si es columna.
2. **Initializers: nunca referenciar clases de `app/` en el nivel superior.**
   Usar `Rails.application.config.to_prepare do ... end` (el prepend es
   idempotente). Cambios en initializers = reinicio obligatorio.
3. **Engine de procesos participativos**: su `ApplicationController` NO
   proporciona `current_participatory_space`; cada controlador lo resuelve
   por `params[:slug]` con ambito de organizacion. El subject correcto del
   permiso de lectura es `:process` (`enforce_permission_to :read, :process`),
   NO `:participatory_space` (deniega aunque el proceso sea publico).
4. **`.layout-item` es una rejilla de 12 columnas**: cualquier hijo directo
   que deba ocupar todo el ancho necesita `grid-column: 1 / -1` (en Firefox
   se aprecia mas si falta).
5. **`content_tag`**: las clases CSS van en `class:`, nunca en `style:`.
6. **Enlaces a proposals desde una pagina a nivel de proceso**: construir el
   proxy por componente (`Decidim::EngineRouter.main_proxy(componente)`), como
   ya se hacia con `admin_proxy`.
7. **Joins de taxonomias: SIEMPRE string SQL** (`.where("decidim_taxonomies.id IN (?)", ids)`);
   la sintaxis hash fallo silenciosamente en esta instalacion.
8. **Columna de orden de taxonomias en 0.31: `weight`** (no `position`).
9. **Excluir borradores**: `where.not(published_at: nil)`.
10. **Accion masiva admin "update taxonomies"**: NO usar sobre el componente
    Propuestas (`UpdateResourcesTaxonomies` reemplaza el set completo de
    taxonomias y borraria los conflictos extra de una propuesta
    multi-conflicto).
11. Deteccion estructural: item "Conflicto N" = el item con hijos; item
    "Pacto" = el item cuya raiz difiere de la del conflicto. Supuestos: un
    conflicto lleva exactamente (item Pacto, item Conflicto N) y "Conflicto N"
    tiene exactamente 1 hijo.

## Pendiente (fases posteriores)
- Boton en la main-bar (`Decidim.menu :menu`).
- Creacion desde el frontend (override de `_edit_form_fields` + TomSelect a
  re-sincronizar).
- Modo "solo consensuada": cuando el ESTADOS_* de un nivel es EXACTAMENTE
  `[:sin_respuesta]`, ese nivel no muestra botones de estado (todos los
  visibles serian "consensuada") y el TITULO del nodo lleva el enlace a la
  proposal consensuada. Aplica independientemente a Pactos, Conflictos y
  Propuestas (ver `solo_consensuadas?(estados)` en el helper). En cualquier
  otro modo el titulo es texto plano y los botones llevan los enlaces.
