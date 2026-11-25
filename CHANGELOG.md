# v0.1.2

- Rediseñada la tarjeta de publicaciones laborales para diferenciarlas visualmente de las publicaciones normales.
- Fondo con gradiente azul, borde y sombra azul para las oportunidades.
- Badge de tipo de oportunidad con icono y color propio por tipo (Empleo, Pasantía, Servicio Social, Freelance).
- Nueva jerarquía visual en oportunidades: Empresa, Tipo, Cargo, Ubicación, Modalidad, Requisitos, Botón principal.
- Unificado el botón de aplicar: se eliminó el CTA "Aplicar aquí" (demo) y se conservó el botón real que usa ApplicationService.
- Eliminada la información repetida: tipo, modalidad y botón ahora aparecen una sola vez por tarjeta.
- Etiqueta "Requisitos" para la descripción de las oportunidades.
- Widgets extraídos para reutilización: ExpandableText y PublicationMedia.
- Se consolidó la renderización de multimedia (mediaItems + medios legados) para evitar duplicados en una misma tarjeta.

# v0.1.1

- Feed modernizado con skeleton loading (shimmer) en carga inicial.
- Búsqueda con debounce de 300ms para mejor rendimiento.
- Estados de error con icono y botón "Reintentar".
- Estados vacíos mejorados visualmente.
- AppBar con gradiente azul.
- Animación de entrada en tarjetas del feed (fade-in + slide-up escalonado).
- Tiempo relativo real en publicaciones (5m, 3h, 2d, 1sem, etc.).
- Texto expandible "Leer más / Mostrar menos" en descripciones largas.
- Animación de escala al dar like.
- Sombra y elevación mejorada en tarjetas.
- Se corrigió el uso de withOpacity (deprecado) por withValues(alpha:).
- Se corrigió temporizador de búsqueda duplicado.

# v0.1.0

- Versión inicial del frontend funcional.
- Pantalla de bienvenida y beneficios.
- Registro de usuario mediante formularios por pasos.
- Inicio de sesión local con persistencia.
- Perfil técnico editable con fotografía y CV.
- Feed de publicaciones con texto, imágenes, videos y documentos.
- Creación de publicaciones con tipo (general, pasantía, empleo, servicio social, freelance, convocatoria).
- Comentarios en publicaciones (CRUD local).
- Publicaciones guardadas.
- Contactos y solicitudes.
- Lista de chats y chat individual local.
- Notificaciones internas.
- Perfil privado.
- Tema claro y oscuro.
- Diseño responsive.
- Integración inicial con backend (auth, publicaciones, contactos, chats, perfiles).
- Autenticación con access tokens y refresh tokens.
- Aplicación a oportunidades.
