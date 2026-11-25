# Arquitectura

## Organización de carpetas

```
lib/
├── core/
│   └── api/
│       └── api_config.dart          # Configuración base de API (baseUrl)
├── helpers/
│   └── profile_helper.dart          # Helpers para perfil de usuario
├── models/
│   ├── comment_model.dart           # Modelo de comentarios
│   ├── contact_model.dart           # Modelo de contactos
│   ├── contact_request_model.dart   # Modelo de solicitudes de contacto
│   ├── notification_model.dart      # Modelo de notificaciones
│   ├── post_model.dart              # Modelo de posts (legado)
│   └── publication_model.dart       # Modelo principal de publicaciones
├── screens/
│   ├── auth/
│   │   ├── login/
│   │   │   └── login_screen.dart
│   │   └── register/
│   │       ├── benefits_screen.dart
│   │       ├── steps/
│   │       │   ├── step_1_screen.dart
│   │       │   ├── step_2_screen.dart
│   │       │   └── step_3_screen.dart
│   │       ├── verification_screen.dart
│   │       └── welcome_screen.dart
│   ├── loading_screen.dart
│   └── main_content/
│       ├── chats/
│       │   ├── chatlist_screen.dart
│       │   └── individual_chat_screen.dart
│       ├── contacts/
│       │   └── contacts_screen.dart
│       ├── home/
│       │   ├── feed_screen.dart
│       │   ├── home_screen.dart
│       │   └── publication_detail_screen.dart
│       ├── notification/
│       │   └── notifications_screen.dart
│       ├── profile/
│       │   ├── profile_screen.dart
│       │   └── widgets/
│       │       ├── profile_header.dart
│       │       ├── profile_technical_tab.dart
│       │       └── saved_publication_screen.dart
│       └── publication/
│           └── newpublication_screen.dart
├── services/
│   ├── api_config.dart              # Configuración de API alternativa
│   ├── application_service.dart     # Postulación a oportunidades
│   ├── auth_service.dart            # Autenticación (login, registro, tokens)
│   ├── chat_service.dart            # Mensajería con backend
│   ├── comment_service.dart         # CRUD local de comentarios
│   ├── contact_service.dart         # Contactos y solicitudes (backend)
│   ├── notification_service.dart    # Notificaciones locales
│   ├── profile_service.dart         # Perfil de usuario (backend)
│   ├── publication_api_service.dart # Publicaciones vía API
│   ├── publication_service.dart     # Publicaciones locales + backend
│   ├── saved_publication_service.dart # Publicaciones guardadas (local)
│   ├── theme_service.dart           # Tema claro/oscuro
│   └── user_service.dart            # Gestión de usuario local
├── utils/
│   └── responsive_helper.dart       # Adaptación a tamaños de pantalla
└── widgets/
    ├── comment_sheet.dart           # Bottom sheet de comentarios
    ├── contacts/
    │   └── contacts_button.dart
    ├── feed/
    │   ├── publication_actions.dart
    │   ├── publication_content.dart
    │   └── publication_header.dart
    ├── media/
    │   └── app_media_player.dart     # Reproductor multimedia
    ├── post_card.dart
    └── publication_card.dart
```

## Providers
No se utiliza un gestor de estado global. El tema se maneja mediante ValueNotifier<ThemeMode> en ThemeService. El resto del estado se maneja mediante SharedPreferences y llamadas directas a servicios.

## Services
Cada servicio encapsula una responsabilidad específica. Los servicios con métodos estáticos (auth_service, contact_service, chat_service, profile_service) interactúan con el backend. Los servicios locales (publication_service, comment_service, notification_service, saved_publication_service) usan SharedPreferences para persistencia.

## Models
Los modelos incluyen métodos toJson()/fromJson() para serialización. PublicationModel es el modelo principal de publicaciones con soporte para multimedia, tipos y visibilidad. PostModel es un modelo legado que coexiste temporalmente.

## Flujo de navegación
- `main.dart` determina la pantalla inicial según sesión activa.
- `_getInitialScreen()` verifica SharedPreferences para decidir entre WelcomeScreen o HomeScreen.
- Las rutas están definidas en MaterialApp.routes.
- El flujo de registro: WelcomeScreen -> BenefitsScreen -> Step1Screen -> Step2Screen -> Step3Screen -> VerificationScreen -> HomeScreen.
- El flujo principal usa HomeScreen con navegación interna a ChatListScreen, NotificationsScreen y ProfileScreen.

## Flujo del backend
- Backend: FastAPI en https://connect-do-api.onrender.com
- Autenticación: POST /auth/login -> access_token + refresh_token
- Registro: POST /auth/register
- Perfil: GET/PATCH /profiles/me
- Publicaciones: GET/POST /publications
- Contactos: GET /contacts, POST /contacts/requests/{id}, etc.
- Chats: GET /chats/conversations, GET/POST /chats/{id}/messages
- Aplicaciones: POST /applications
- Los tokens se almacenan en SharedPreferences y se envían como Bearer token.

## Dependencias principales
- Flutter SDK
- image_picker
- file_picker
- flutter_svg
- phosphoricons_flutter
- url_launcher
- shared_preferences
- share_plus
- video_player
- just_audio
- http
