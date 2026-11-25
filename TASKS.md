# Sprint 1.1 — Optimización UX/UI de Publicaciones de Oportunidades

> ## ESTADO: COMPLETADO ✅
> Fecha de finalización: 30 de julio de 2026
> Detalles, decisiones y archivos modificados en la sección "Sprint 1.1 COMPLETADO" al final de este documento.

Lee completamente la documentación del proyecto antes de comenzar:

- README.md
- API.md
- ARCHITECTURE.md
- CHANGELOG.md
- PROJECT_STATUS.md
- TASKS.md

El objetivo NO es agregar nuevas funcionalidades.

El objetivo es perfeccionar la experiencia de usuario de las publicaciones de oportunidades laborales dentro del Feed.

IMPORTANTE:

Trabaja únicamente sobre publicaciones de tipo:

- Empleo
- Pasantía
- Servicio Social
- Freelance

NO modificar la experiencia de publicaciones normales de usuarios.

------------------------------------------------

OBJETIVOS

1. Eliminar elementos duplicados.

Actualmente existen dos botones para aplicar.

Debe quedar un único botón principal.

Analiza cuál CTA tiene mayor sentido conservar.

Elimina completamente el otro junto con cualquier elemento redundante asociado.

------------------------------------------------

2. Diferenciar visualmente las publicaciones laborales.

Actualmente una publicación de empleo luce casi igual a una publicación normal.

Rediseña la tarjeta para que inmediatamente sea reconocible como una oportunidad laboral.

Puedes reorganizar la información existente.

No elimines información importante.

------------------------------------------------

3. Mejorar la jerarquía visual.

La información debe tener un orden claro.

Priorizar:

- Empresa
- Tipo de oportunidad
- Cargo
- Ubicación
- Modalidad
- Requisitos
- Botón principal

------------------------------------------------

4. Eliminar información repetida.

No mostrar dos veces:

- modalidad
- tipo
- botones
- etiquetas

Cada dato debe aparecer una sola vez.

------------------------------------------------

5. Revisar el diseño completo de la tarjeta.

Analiza:

- espacios
- alineaciones
- tamaños
- colores
- contraste
- consistencia visual

Haz mejoras donde sea necesario.

------------------------------------------------

6. Corregir errores encontrados.

Si durante el análisis detectas errores relacionados con el Feed o las publicaciones laborales:

- corrígelos

Siempre que la corrección no afecte otras pantallas.

------------------------------------------------

7. Optimización.

Refactoriza únicamente si mejora:

- legibilidad
- mantenimiento
- rendimiento

No hagas cambios innecesarios.

------------------------------------------------

RESTRICCIONES

NO modificar:

- Login
- Registro
- Perfil
- Chats
- Contactos
- Notificaciones
- Backend
- API

Trabajar únicamente sobre el Feed y las publicaciones laborales.

------------------------------------------------

AL FINALIZAR

Actualizar:

- PROJECT_STATUS.md
- CHANGELOG.md
- TASKS.md

Marcar este Sprint como COMPLETADO.

Documentar:

- archivos modificados
- errores encontrados
- errores corregidos
- decisiones de UX tomadas
- mejoras implementadas

Compilar el proyecto.

Corregir cualquier error generado.

No continuar con otro Sprint.

Detenerte completamente al finalizar.

-----------------------------------------------

## Sprint 1.1 COMPLETADO — Documentación

### Archivos modificados
- `lib/models/publication_model.dart` — getters `hasLegacyMedia` y `hasAnyMedia`.
- `lib/widgets/publication_card.dart` — despacha a la nueva tarjeta de oportunidades; eliminado el CTA duplicado `_ApplyOpportunityButton`.
- `lib/widgets/feed/publication_content.dart` — se simplificó: elimina badge, chips y modal demo de aplicar; solo texto.
- `lib/widgets/feed/expandable_text.dart` — (nuevo) texto expandible reutilizable.
- `lib/widgets/feed/publication_media.dart` — (nuevo) renderizado unificado de multimedia (mediaItems + legados).
- `lib/widgets/feed/opportunity_card.dart` — (nuevo) tarjeta rediseñada para oportunidades con único CTA real.

### Errores encontrados
1. Existían dos botones para aplicar: "Aplicar aquí" (modal demo que no guardaba en backend) y "Aplicar a esta oportunidad" (real).
2. Tipo de oportunidad duplicado: badge en el contenido y de nuevo en el contenedor del botón.
3. Modalidad duplicada: chip en el contenido y pill en el contenedor del botón.
4. Multimedia podía renderizarse dos veces cuando coexistían mediaItems y ruta legada.

### Errores corregidos
- Se conservó el CTA real (ApplicationService) y se eliminó el flujo demo por completo.
- Tipo y modalidad ahora aparecen una sola vez cada uno.
- Se consolidó la multimedia en un solo widget para evitar duplicados.
- Se protegió el uso de mounted en el bloque finally del flujo de aplicar.

### Decisiones de UX tomadas
- CTA principal único: "Aplicar a esta oportunidad" (full width, destacado).
- Tarjeta diferenciada: gradiente azul, badge de tipo con icono y color por tipo (Empleo, Pasantía, Servicio Social, Freelance).
- Jerarquía: Empresa -> Tipo -> Cargo -> Ubicación -> Modalidad -> Requisitos -> Botón principal.
- Las publicaciones normales y las convocatorias (announcement) conservan la tarjeta estándar.

### Mejoras implementadas
- Legibilidad: etiqueta "Requisitos", mayor peso tipográfico en el cargo, espacios y alineaciones consistentes.
- Mantenimiento: widgets reutilizables `ExpandableText` y `PublicationMedia`; `OpportunityCard` autocontenida.
- Rendimiento: sin cambios de algoritmos; se evitó el rebuild innecesario de componentes duplicados.

### Verificación
- `flutter analyze`: sin issues nuevos (5 issues preexistentes ajenos a este sprint).
- `flutter test`: 1/1 pruebas aprobadas.
- `flutter build apk --release`: compilación exitosa (56.5MB).

No continuar con otro Sprint.