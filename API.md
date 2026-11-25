# API — Connect Do

Base URL: `https://connect-do-api.onrender.com`

## Autenticación

### POST /auth/register
| Campo | Tipo | Descripción |
|-------|------|-------------|
| email | string | Correo del usuario |
| password | string | Contraseña |
| first_name | string | Nombre |
| last_name | string | Apellido |

**Respuesta:** 200/201 — Usuario creado

**Pantalla:** Step1Screen, Step2Screen, Step3Screen

---

### POST /auth/login
| Campo | Tipo | Descripción |
|-------|------|-------------|
| email | string | Correo del usuario |
| password | string | Contraseña |

**Respuesta:**
```json
{
  "access_token": "string",
  "refresh_token": "string"
}
```

**Pantalla:** LoginScreen

---

### GET /auth/me
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** Datos del usuario autenticado

**Pantalla:** AuthService (post-login)

---

## Perfiles

### GET /profiles/me
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** Datos del perfil del usuario actual

**Pantalla:** ProfileScreen, AuthService

---

### PATCH /profiles/me
**Headers:** Authorization: Bearer {access_token}

| Campo | Tipo | Descripción |
|-------|------|-------------|
| phone | string | Teléfono |
| university | string | Universidad |
| academic_level | string | Nivel académico |
| career | string | Carrera |
| academic_cycle | string | Ciclo académico |
| bio | string | Descripción |
| portfolio_url | string | URL del portafolio |
| avatar_url | string | URL del avatar |
| profile_image_base64 | string | Imagen de perfil en base64 |
| cv_url | string | URL del CV |
| is_private | bool | Perfil privado |

**Respuesta:** Perfil actualizado

**Pantalla:** ProfileScreen, AuthService

---

## Publicaciones

### GET /publications
**Headers:** Authorization: Bearer {access_token}

**Parámetros query:**
| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| limit | int | Límite de resultados (default: 20) |
| offset | int | Desplazamiento (default: 0) |
| type | string | Filtrar por tipo |

**Respuesta:** `List<PublicationModel>`

**Pantalla:** FeedScreen, HomeScreen

---

### POST /publications
**Headers:** Authorization: Bearer {access_token}

| Campo | Tipo | Descripción |
|-------|------|-------------|
| title | string | Título |
| description | string | Descripción |
| type | string | Tipo (general, internship, job, social_service, freelance, announcement) |
| location | string | Ubicación |
| modality | string | Modalidad (remote, onsite, hybrid) |
| visibility | string | Visibilidad (public, contacts, private) |
| image_url | string | URL de imagen |
| media_items | List | Items multimedia |

**Respuesta:** PublicationModel creado

**Pantalla:** NewPublicationScreen

---

### DELETE /publications/{id}
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** 200/202/204

**Pantalla:** PublicationDetailScreen

---

## Contactos

### GET /contacts/users/search?q={query}&limit={limit}
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** Lista de usuarios encontrados

**Pantalla:** ContactsScreen

---

### POST /contacts/requests/{receiver_id}
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** Solicitud creada

**Pantalla:** ContactsScreen

---

### GET /contacts/requests/incoming
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** Lista de solicitudes recibidas

**Pantalla:** ContactsScreen

---

### GET /contacts/requests/outgoing
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** Lista de solicitudes enviadas

**Pantalla:** ContactsScreen

---

### POST /contacts/requests/{request_id}/accept
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** Solicitud aceptada

**Pantalla:** ContactsScreen

---

### POST /contacts/requests/{request_id}/reject
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** Solicitud rechazada

**Pantalla:** ContactsScreen

---

### GET /contacts
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** Lista de contactos aceptados

**Pantalla:** ContactsScreen

---

## Chats

### GET /chats/conversations
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** Lista de conversaciones

**Pantalla:** ChatListScreen

---

### GET /chats/{contact_id}/messages?limit={limit}&offset={offset}
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** Lista de mensajes

**Pantalla:** IndividualChatScreen

---

### POST /chats/{contact_id}/messages
**Headers:** Authorization: Bearer {access_token}

| Campo | Tipo | Descripción |
|-------|------|-------------|
| content | string | Contenido del mensaje |

**Respuesta:** Mensaje creado

**Pantalla:** IndividualChatScreen

---

### PATCH /chats/{contact_id}/read
**Headers:** Authorization: Bearer {access_token}

**Respuesta:** 200 — Mensajes marcados como leídos

**Pantalla:** IndividualChatScreen

---

## Aplicaciones

### POST /applications
**Headers:** Authorization: Bearer {access_token}

| Campo | Tipo | Descripción |
|-------|------|-------------|
| publication_id | string | ID de la publicación |
| cover_message | string | Mensaje de postulación |

**Respuesta:** 200/201 — Aplicación creada

**Códigos de error:** 409 (ya aplicaste), 400 (tu propia publicación), 401/403 (sesión expirada)

**Pantalla:** PublicationDetailScreen
