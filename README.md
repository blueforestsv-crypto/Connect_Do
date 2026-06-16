# Connect Do

Connect Do es una aplicación móvil desarrollada en Flutter que busca conectar estudiantes universitarios con otros estudiantes, empresas y oportunidades de crecimiento académico y profesional.

La plataforma funciona como una red social profesional universitaria donde los usuarios pueden crear un perfil técnico, mostrar sus habilidades, publicar contenido, compartir archivos, establecer contactos e interactuar dentro de una comunidad enfocada en el desarrollo profesional.

## Estado del proyecto

Connect Do se encuentra actualmente en etapa de desarrollo y preparación para integración con backend.

La versión actual corresponde al frontend funcional de la aplicación, con almacenamiento local y navegación entre los principales módulos.

## Funcionalidades actuales

* Pantalla de bienvenida y presentación de beneficios.
* Registro de usuario mediante formularios por pasos.
* Inicio de sesión local.
* Persistencia de sesión.
* Perfil técnico editable.
* Fotografía de perfil.
* Carga de curriculum vitae.
* Feed de publicaciones.
* Creación de publicaciones.
* Publicaciones con texto, imágenes, videos y documentos.
* Comentarios en publicaciones.
* Publicaciones guardadas.
* Contactos y solicitudes.
* Lista de chats.
* Chat individual local.
* Notificaciones internas.
* Perfil privado.
* Tema claro y oscuro.
* Diseño adaptable a distintos tamaños de pantalla.
* Reproducción de contenido multimedia.

## Tecnologías utilizadas

* Flutter
* Dart
* SharedPreferences
* File Picker
* Image Picker
* Video Player
* Just Audio
* Phosphor Icons
* Flutter SVG

## Arquitectura actual

El proyecto se encuentra organizado mediante:

```text
lib/
├── models/
├── screens/
├── services/
├── utils/
├── helpers/
└── widgets/
```

La versión actual utiliza servicios y almacenamiento local. En la siguiente etapa se integrará una API real y almacenamiento remoto.

## Próxima etapa

La próxima fase contempla:

* Backend desarrollado con FastAPI.
* Base de datos PostgreSQL.
* Docker y Docker Compose.
* Autenticación mediante access tokens y refresh tokens.
* Verificación de correo.
* Recuperación de contraseña.
* Almacenamiento remoto de fotografías, videos, documentos y CV.
* Feed paginado.
* Notificaciones reales.
* Moderación de contenido.
* Chat en tiempo real.
* Entornos de desarrollo, staging y producción.
* Publicación en Google Play y App Store.

## Ejecución local

Clonar el repositorio:

```bash
git clone https://github.com/blueforestsv-crypto/Connect_Do.git
```

Entrar en la carpeta:

```bash
cd Connect_Do
```

Instalar dependencias:

```bash
flutter pub get
```

Ejecutar la aplicación:

```bash
flutter run
```

## Verificación del proyecto

Ejecutar análisis estático:

```bash
flutter analyze
```

Ejecutar pruebas:

```bash
flutter test
```

Generar APK de producción:

```bash
flutter build apk --release
```

## Versionado

Connect Do utiliza versionado semántico:

```text
MAJOR.MINOR.PATCH
```

Ejemplos:

```text
v0.1.0 — Frontend funcional inicial
v0.2.0 — Integración de autenticación y backend
v0.3.0 — Publicaciones y multimedia remotas
v1.0.0 — Primera versión pública estable
```

## Estado de producción

La aplicación todavía no debe utilizarse con datos reales o sensibles hasta completar:

* Autenticación segura.
* Backend.
* Base de datos remota.
* Almacenamiento privado.
* Políticas de privacidad.
* Moderación.
* Pruebas de seguridad.
* Monitoreo.
* Preparación para tiendas.

## Equipo

Proyecto desarrollado por Blue Forest.

## Licencia

El código fuente es privado y pertenece al equipo responsable de Connect Do. No se permite su distribución, modificación o uso sin autorización.
