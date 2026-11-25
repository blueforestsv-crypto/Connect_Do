# CONNECT DO

## Estado general
El proyecto se encuentra en etapa de desarrollo activo (v0.1.0). El frontend funcional está completo con almacenamiento local y navegación entre módulos principales. Se ha iniciado la integración con backend remoto (FastAPI + PostgreSQL) con autenticación por tokens y endpoints para publicaciones, contactos, chats y perfiles.

## Última actualización
30 de julio de 2026 — Sprint 1.1 completado (UX/UI de publicaciones de oportunidades)

## Arquitectura actual
- Frontend: Flutter 3.x (Dart SDK ^3.7.2)
- Arquitectura: capas (models, services, screens, widgets, utils, helpers)
- Almacenamiento local: SharedPreferences
- Backend: API REST en https://connect-do-api.onrender.com
- Autenticación: access tokens + refresh tokens
- Sin gestor de estado global (ValueNotifier para tema)

## Funcionalidades implementadas
- Pantalla de bienvenida y beneficios
- Registro de usuario por pasos (Step 1, 2, 3)
- Verificación de correo
- Inicio de sesión local y remoto
- Persistencia de sesión
- Perfil técnico editable con fotografía y CV
- Feed de publicaciones con texto, imágenes, videos y documentos
- Creación de publicaciones con tipo (general, pasantía, empleo, servicio social, freelance, convocatoria)
- Comentarios en publicaciones (CRUD local)
- Publicaciones guardadas
- Contactos y solicitudes (enviar, aceptar, rechazar)
- Búsqueda de usuarios
- Lista de conversaciones / chats
- Chat individual (mensajes con backend)
- Notificaciones internas
- Perfil privado
- Tema claro y oscuro
- Diseño responsive
- Aplicación a oportunidades

## Funcionalidades pendientes
- Backend completo con FastAPI (en progreso)
- Base de datos PostgreSQL
- Docker y Docker Compose
- Verificación de correo real
- Recuperación de contraseña
- Almacenamiento remoto de multimedia
- Feed paginado
- Notificaciones push reales
- Moderación de contenido
- Chat en tiempo real (WebSocket)
- Entornos development, staging, production
- Publicación en Google Play y App Store
- Políticas de privacidad
- Pruebas de seguridad

## Errores conocidos
- Dos clases ApiConfig duplicadas (lib/core/api/api_config.dart y lib/services/api_config.dart)
- PostModel y PublicationModel coexisten sin migración completa
- Likes solo persistidos localmente
- ContactService.getRequests() mezcla lógica local y remota
- Sin manejo centralizado de errores HTTP
- Sin refresh automático de tokens

## Errores corregidos durante esta sesión
- Tiempo hardcodeado "Ahora" reemplazado con tiempo relativo real en PublicationHeader
- withOpacity deprecado reemplazado por withValues(alpha:) en publication_card.dart
- Búsqueda sin debounce optimizada con Timer de 300ms

## Sprint 1.1 — UX/UI de publicaciones de oportunidades (COMPLETADO)

### Objetivo
Perfeccionar la experiencia de usuario de las publicaciones de oportunidades laborales
(Empleo, Pasantía, Servicio Social, Freelance) dentro del Feed. Sin nuevas funcionalidades.

### Decisiones de UX tomadas
- Se conservó como CTA principal el botón "Aplicar a esta oportunidad" (usa ApplicationService
  con el backend real). Se eliminó el botón "Aplicar aquí" que abría un modal demo que no guardaba
  la postulación.
- Se eliminó el modal "Versión demo" de postulación de PublicationContent por ser redundante y engañoso.
- Cada dato aparece una sola vez: el tipo se muestra en el badge superior, la modalidad solo como chip,
  y existe un único botón de aplicar.
- La tarjeta de oportunidades se distingue con gradiente azul, badge de tipo con icono y color por tipo,
  y mayor peso tipográfico en el cargo.
- Jerarquía visual de oportunidades: Empresa -> Tipo -> Cargo -> Ubicación -> Modalidad -> Requisitos -> Botón principal.
- Los anuncios (announcement) y las publicaciones normales conservan su tarjeta estándar.

### Errores encontrados y corregidos
- Dos botones de aplicar en cada oportunidad (uno funcional y uno demo) -> se unificó en uno solo.
- Tipo y modalidad duplicados (badge + contenedor + chips) -> cada dato aparece una sola vez.
- El modal "Aplicar aquí" mostraba "Versión demo: la aplicación aún no se guarda en backend"
  mientras existía un botón real -> se eliminó el flujo demo.
- Multimedia renderizada dos veces cuando coexistían mediaItems y ruta legada -> se consolidó
  en un solo widget PublicationMedia.
- use_build_context_synchronously potencial en el flujo de aplicar -> se protegió con mounted en finally.

### Archivos modificados
- `lib/models/publication_model.dart`
- `lib/widgets/publication_card.dart`
- `lib/widgets/feed/publication_content.dart`
- `lib/widgets/feed/expandable_text.dart` (nuevo)
- `lib/widgets/feed/publication_media.dart` (nuevo)
- `lib/widgets/feed/opportunity_card.dart` (nuevo)

### Verificación
- `flutter analyze`: sin nuevos issues (5 issues preexistentes ajenos a este sprint).
- `flutter test`: 1/1 pruebas aprobadas.
- `flutter build apk --release`: compilación exitosa (56.5MB).

## Archivos modificados (Sprint 1)
- `lib/screens/main_content/home/feed_screen.dart`
- `lib/widgets/publication_card.dart`
- `lib/widgets/feed/publication_header.dart`
- `lib/widgets/feed/publication_content.dart`
- `lib/widgets/feed/publication_actions.dart`

## Próximo sprint recomendado
- Implementar carga paginada real desde el backend
- Agregar WebSocket para chat en tiempo real
- Unificar las dos clases ApiConfig
- Refactorizar manejo de tokens con refresh automático

## Riesgos detectados
- Token de acceso sin renovación automática puede romper la sesión
- Duplicidad de modelos y servicios puede generar inconsistencias
- Dependencia total de SharedPreferences sin respaldo en backend
- Sin testing automatizado en servicios de API

## Notas importantes
- El proyecto usa dos referencias distintas para API config
- El backend actual corre en Render (gratuito, puede tener latencia)
- La aplicación no debe usarse con datos reales hasta completar seguridad
