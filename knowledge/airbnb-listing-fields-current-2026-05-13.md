# AirBnB Listing Fields — Inventory 2026-05-13

Contenido actual de los campos editables del AirBnB hosting editor para los 4 listings activos. Extraído vía Chrome MCP (Claude in Chrome extension en sesión Alex logged in).

**Date**: 2026-05-13
**Source**: Chrome MCP browser session, `airbnb.mx/hosting/listings/editor/{listingId}/{section}` URL pattern
**Method**: `mcp__Claude_in_Chrome__navigate` + `get_page_text` × 4 listings × 3 working URLs

---

## 0. Summary

### URL changes (vs WC expected)

WC asumía 10 URLs por listing (40 total). AirBnB consolidó UI desde la última vez. **Solo 3 URLs por listing funcionan**, las otras 7 devuelven 404:

| URL pattern | Status | Cubre |
|---|---|---|
| `/details/title` | ✅ works | Title ES + EN (length only en single-tab view) |
| `/details/description` | ✅ works | Description + Tu propiedad + Acceso huéspedes + Interacción + Otros detalles (5 sub-fields consolidados) |
| `/arrival/directions` | ✅ works | Cómo llegar + Método de llegada + Datos del wifi + Manual de la casa + Reglas + Instrucciones salida (6 sub-fields consolidados) |
| `/details/the-space` | ❌ 404 | (legacy URL, content now under `/details/description`) |
| `/details/guest-access` | ❌ 404 | (legacy URL) |
| `/details/other` | ❌ 404 | (legacy URL) |
| `/house-rules` | ❌ 404 | (legacy URL) |
| `/amenities` | ❌ 404 | (legacy URL, amenities visible en sidebar overview only) |
| `/arrival/house-manual` | (not tested) | likely 404, content en `/arrival/directions` |
| `/arrival/check-in-method` | (not tested) | likely 404, content en `/arrival/directions` |

**Total content extraído**: 4 listings × 3 URLs = 12 page fetches. ~25K chars.

### Stats por listing

| Listing | AirBnB ID | Title chars ES | Title chars EN | Description main | Tu propiedad | Manual casa | Reseñas declaradas |
|---|---|---|---|---|---|---|---|
| **Rincón del Mar** | 18780853 | 39/50 | 47/50 ✅ | "168 reseñas" | DETAILED + emojis | brief (WiFi + caja) | 168 |
| **Las Morenas** | 733868075691217916 | 47/50 | 29/50 ✅ | "128 reseñas" + ⭐4.8 | VERY DETAILED 6 hab specs | brief (WiFi + caja) | 128 |
| **Combinada (Dos Villas)** | 18009632 | 43/50 | — | "más de 180 reseñas" | PARAGRAPH + bullet | **EMPTY** 🔴 | 180+ |
| **Huerta Cocotera** | 1577678927412395161 | 40/50 | — | (no reviews mention) | EXPERIENTIAL + animales | DETAILED 6 sections | — |

---

## 1. Per-property content

### 1.1 Rincón del Mar (18780853, room 78695)

#### Title

```
Título (ES, 39/50): Villa a pie de playa, chef, 30 personas
Título (EN, 47/50): [exists but tab not clicked to extract]
Nombre interno (23/40): [private to Alex]
```

#### Description (Description del anuncio — short hook, 500 chars limit)

```
🏅 Villa Favorita en Airbnb — una de las villas frente al mar mejor calificadas en la Costa del Pacífico Mexicano.

Da el primer paso y quédate sin palabras: la alberca infinita, el océano y el cielo se funden en un solo horizonte. Bienvenido a Villa Rincón del Mar.

💬 Más de 168 reseñas de 5 estrellas avalan nuestro servicio. ¡Te esperamos!
```

#### Tu propiedad (long-form, ~2000 chars)

```
Villa completa con acceso directo a la playa, diseñada por un arquitecto mexicano de renombre. Arquitectura abierta y minimalista, materiales naturales, brisa marina permanente. 6 habitaciones · 18 camas · 6.5 baños · hasta 30 huéspedes:

🛏️ Suite principal con terraza privada y vista al mar — hasta 5 personas
🛏️ 3 habitaciones para 5 personas c/u
🛏️ 1 habitación para 7 personas
🛏️ 1 habitación para 3 personas

Todas las recámaras incluyen: A/C, WiFi, clóset, baño completo, toallas de habitación y playa, amenidades de baño.

✅ Servicios Incluidos
Todo esto forma parte de tu estancia, sin costo adicional:
👨‍🍳 Chef y cocinera a tu disposición — menú completo disponible, con especialidades como huachinango a la talla al carbón, ceviche peruano de pez vela y cortes mexicanos, americanos y argentinos
🏊 Alberca infinita con palapa-bar frente al océano
🏖️ Área lounge en playa con camastros y hamacas
🧹 Limpieza diaria de habitaciones (cambio de sábanas semanal, toallas cada 3 días)
🎵 Sistema de audio y TV
🛻 Apoyo en renta de camionetas para hasta 20 personas, con o sin chofer
🛥️ Coordinación de renta de yates y lanchas

🛎️ Servicios Adicionales (costo aparte)
Personaliza tu estancia. Contáctanos antes de reservar y te enviamos lista de precios completa:
🍹 Servicio de bebidas en palapa-bar y playa
🛒 Compra y surtido de alimentos y bebidas previa llegada
🔥 Fogata en la playa
🥥 Cocos frescos al momento
💆 Masajes en sitio
🐴 Paseo a caballo
🚣 Tour en la Laguna de Coyuca
🤿 Buceo, snorkel, pesca y esquí acuático
```

#### Acceso de los huéspedes

```
Los huéspedes pueden disfrutar todas las áreas e instalaciones de la villa. El servicio de habitación se proporciona tres días de la semana, para estancias largas el cambio de sábanas es semanal, cambio de toallas cada tres días..
```

#### Interacción con los huéspedes

```
Nuestro conserje puede apoyar con lo que requieres antes y durante tu estancia y podemos apoyarte en la planeación de excursiones y actividades. Resolvemos todas tus dudas cuantas veces sea necesario por medio de teléfono o whats una vez realizada la reservación.
```

#### Otros detalles a destacar

```
[EMPTY — "Agregar detalles"]
```

#### Cómo llegar (Directions) — ~5,300 chars

Contenido idéntico al Kit Welcome RdM en `whatsapp-kits-current-2026-05-13.md`. 6 secciones (viaje/llegada, servicio cocina, supermercados, actividades, restaurantes, eventos). Differences vs kit WhatsApp:

| WhatsApp kit | AirBnB Directions field |
|---|---|
| "Mercado de Pescado y Mariscos, a 20 minutos" | "Pescadería 'La More', a un kilómetro... camarones congelados y pescado fresco, servicio a domicilio: +52 744 551 5239" |
| (sin mención) | Agregado "Mariscos 'Doña Lety', a un kilómetro... +52 744 1460 216" en sección restaurantes |

Resto idéntico al kit WhatsApp.

#### Método de llegada

```
Caja de seguridad para llaves
```

#### Datos del wifi

```
Red: rincondelmar
Contraseña: rincondelmar
```

#### Manual de la casa

```
Wifi: rincondelmar, contraseña: rincondelmar

El boiler normalmente esta apagado, ya que el agua es tibia por el calor. Si quieren prender el boiler esta atras de la cocina en el area de servicio.

Cada habitacion cuenta con una caja de seguridad, nuestra encargada les puede dar el codigo de aceso. No nos hacemos responsables por efectivo o cosas de valor que no se guardan en las cajas de seguridad.
```

#### Instrucciones para la salida

```
[EMPTY — "Agregar detalles"]
```

#### Reglas / metadata (sidebar)

- Llegada: 3:00 p.m.
- Salida: 11:00 a.m.
- Capacidad: 16 o más huéspedes
- Cancelación: Superestricta de 30 días
- Preferencias interacción: "Me gusta saludar en persona, pero fuera de eso, no convivo mucho."
- Ubicación: C. Puerto Marques 17, Playa Hermosa Vicente Guerrero, 40989 San Nicolás de las Playas, Gro., Mexico
- Enlace personalizado: https://airbnb.mx/h/acapulco-villa-sobre-playa-chef-servicio-27-personas

---

### 1.2 Las Morenas (733868075691217916, room 74322)

#### Title

```
Título (ES, 47/50): Villa frente mar · 30 huéspedes · Chef opcional
Título (EN, 29/50): [exists, not extracted]
Nombre interno (12/40): [private]
```

#### Description

```
🌊 50 m del Pacífico. 30 personas. Una villa entera para ti.

Alberca privada 11×5 m, 6 habitaciones con baño propio, vista al mar y acceso directo a Playa Barra de Coyuca. Todo fluye: terraza, palapa-bar, comedor y brisa del mar todo el día.

🍳 Agrega servicio de chef y que alguien más cocine mientras tú disfrutas.

⭐ 4.8 · 128 reseñas · SuperAnfitrión

La reunión que todos van a recordar empieza aquí. 🐚
```

#### Tu propiedad (long-form, ~2400 chars)

```
Da un paso y el mar ya está ahí. Imagínalo: abres la puerta de Villa Rincón de las Morenas y al fondo del pasillo, entre palmeras, el agua turquesa de la alberca te da la bienvenida — con el océano Pacífico apenas 50 metros más allá. Esa imagen lo dice todo.

Esta villa fue diseñada por un arquitecto mexicano de renombre para grupos que quieren disfrutar juntos sin sacrificar comodidad. Todo el espacio fluye: la alberca de 11×5 m, la terraza palapa-bar, el amplio comedor y la sala se conectan en un solo ambiente abierto donde la brisa del mar corre libre todo el día.

¿Para quién es esta villa?
Perfecta para reuniones familiares grandes, grupos de amigos, retiros corporativos, cumpleaños o bodas íntimas en la playa. Con 6 habitaciones y capacidad para hasta 30 personas, es uno de los pocos lugares en Acapulco donde todos pueden quedarse bajo el mismo techo.

Lo que incluye:
🏖️ Acceso directo a la playa a 50 m
🏊 Alberca privada 11×5 m + chapoteadero para niños 4×3 m
🛏️ 6 habitaciones amplias con A/C, ventilador, WiFi, clóset y baño
🌊 Vista al mar desde la habitación principal
🏄 Apoyo para rentar yates, camionetas, excursiones, buceo y más
🐾 Se aceptan mascotas

Servicio de chef (opcional) — el toque que lo cambia todo:
Por $1,000/día (hasta 20 personas) dos cocineras preparan los tres alimentos, hacen las compras antes de tu llegada y mantienen la villa limpia durante tu estancia. Para grupos de 21 a 30 personas, el servicio es $1,500/día con tres cocineras y un mozo. Reserva con anticipación — es el servicio favorito de nuestros huéspedes.

Las habitaciones:
🛏️ Hab. 1 — 3 personas · Cama king + 1 individual · 🌊 Vista al mar
🛏️ Hab. 2 — 7 personas · 3 camas matrimoniales + 2 individuales · 🌊 Vista al mar
🛏️ Hab. 3 — 4 personas · 2 camas matrimoniales
🛏️ Hab. 4 — 4 personas · 3 camas matrimoniales + 1 individual
🛏️ Hab. 5 — 4 personas · 2 camas matrimoniales
🛏️ Hab. 6 — 8 personas · 2 camas matrimoniales

Tu playa, tu ritmo:
Amanece con café frente al Pacífico. A media mañana, paseo en lancha por la Laguna de Coyuca. Por la tarde, voleibol en la playa o siesta en la hamaca. Al atardecer, fogata bajo un cielo lleno de estrellas.

Todo esto a 20 minutos del centro de Acapulco. Alexander y su equipo responden en menos de una hora y te ayudan a organizar cada detalle desde el momento en que reservas.

¿Necesitan espacio para más de 30 personas? Nuestra Villa Rincón del Mar está a unos pasos, directamente sobre la playa, con 6 habitaciones adicionales para hasta 28 personas más. Escríbenos y lo coordinamos todo.

Con más de 128 reseñas y calificación de ⭐ 4.8, Villa Rincón de las Morenas es el punto de encuentro favorito de las familias y grupos que visitan la costa del Pacífico.
```

#### Acceso de los huéspedes

```
Los huéspedes pueden disfrutar todas las áreas e instalaciones de la villa..
```

#### Interacción con los huéspedes

```
Estamos disponibles en la propiedad para apoyarte en la planeación de excursiones y actividades. Resolvemos todas tus dudas cuantas veces sea necesario por medio de teléfono o whats una vez realizada la reservación.
```

#### Otros detalles a destacar

```
[EMPTY]
```

#### Cómo llegar (Directions) — ~5,600 chars

Idéntico estructura a Kit Welcome Morenas en `whatsapp-kits-current-2026-05-13.md`. Sección 2 servicio cocina **DECLARA EXPLÍCITAMENTE OPCIONAL** con precios $1,000 (hasta 16) / $1,500 (>16), tres personas. Esto **CONTRADICE** templates AirBnB ES `3 - Morenas completa` (omite servicio) y `3a Morenas english` (dice "included"). Verdad operacional confirmada: OPCIONAL.

Otras differences vs kit WhatsApp:
- Tienda "El Guero" (sin diéresis) confirmada en Directions (kit Morenas dice "El Guero", kit RdM dice "El Güero")
- "Pescadería La More" agregada
- "Mariscos Doña Lety" agregada
- Resto idéntico al kit Morenas

#### Método de llegada

```
Caja de seguridad para llaves
```

#### Datos del wifi

```
Red: Rincondelmar1
Contraseña: Rincondelmar1
```

🔴 **WiFi password DIFFERENT** vs RdM/Combinada/Huerta (que usan "rincondelmar" sin "1").

#### Manual de la casa

```
Wifi: Rincondelmar1, contraseña: Rincondelmar1

La casa cuenta con una caja de seguridad, nuestra encargada les puede dar el codigo de aceso. No nos hacemos responsables por efectivo o cosas de valor que no se guardan en la caja de seguridad.
```

#### Instrucciones para la salida

```
[EMPTY]
```

#### Reglas / metadata

- Llegada: 3:00 p.m.
- Salida: 11:00 a.m.
- Capacidad: 16 o más huéspedes
- Cancelación: Estricta (vs Superestricta 30 días en RdM/Combinada)
- Preferencias interacción: "No estaré presente, así que prefiero comunicarme a través de la app."
- Ubicación: C. Puerto Manzanillo 15, 40989 Gro., Mexico
- Enlace personalizado: https://airbnb.mx/h/acapulco-villa-pie-playa-28-personas-chef

---

### 1.3 Combinada (Dos Villas) (18009632, room 74316)

#### Title

```
Título (ES, 43/50): Dos villas, pie de playa, chef, 58 personas
Título (EN): NO existe EN version
Nombre interno (10/40): [private]
```

#### Description

```
El espacio idoneo para tu reunion familiar o de negocio.

Villa Rincón del Mar:
- A pie de playa, acceso directo al mar
- 6 habitaciones para hasta 28 huéspedes

Villa Rincon de las Morenas:
- Playa a pocos pasos y a 70 m de la otra casa
- 6 habitaciones para hasta 30 huéspedes
- Servicio de cocina por chef y cocineras
```

#### Tu propiedad

```
Te elaboramos una propuesta detallada para tu reunión familiar o corporativa! AirBnB unicamente permite agregar 16 personas en el sistema, que es menos que el cupo de una sola casa. Envienos un mensaje con las fechas deseadas, el numero de personas, y detalles de su reunión para poder enviarle una propuesta.

Nuestro servicio incluye:
- Preparación de alimentos, elaborado menu disponible
- Parrilladas y mariscadas en nuestro asador de lujo a la vista
- Limpieza diario de habitaciones
- Sillas y sombrillas para la playa, toallas de baño y playa, jabon, shampoo, sistema audio y TV.
- Apoyo en renta de camionetas hasta 20 personas con/sin chofer desde tu origen
- Organización de renta de yates y lanchas para tour, buceo, snorkel, pesca, esquí acuático y mas

Servicio adicional disponibles:
- Compra de alimentos y bebidas
- Preparación de bebidas en palapa bar y playa
- Fogatas en la playa
- Cocos frescos
- Masajes y tour en caballos
- Tour en la laguna

Nuestros huéspedes aman nuestro servicio, mas de 180 reseñas de 5 estrellas! Opcionalmente, nuestro chef y una cocinera están a tu disposición, y se pueden encargar también de realizar las compras de alimentos y bebidas según tus requerimientos antes de tu llegada.

Deleita tu paladar con nuestras especialidades: Huachinango a la talla preparado al carbón y fresco ceviche peruano de pez vela. Cortes mexicanos, americanos o argentinos en un término perfecto. O cualquier otro platillo favorito tuyo.

Te ayudamos a planear tu estancia desde el momento de hacer tu reservación. Te apoyamos organizando transporte local, eventos en la playa, excursiones, buceo, pesca, paseos a la laguna de Coyuca, deportes acuáticos, masajes en el sitio, o prácticamente cualquier cosa que te puedas imaginar.

Bienvenido a Villa Rincón del Mar y Villa Rincon de las Morenas, y que inicié la aventura.
```

🔴 **Inconsistencia en mismo field**: dice "Nuestro servicio incluye: Preparación de alimentos" + después "Opcionalmente, nuestro chef y una cocinera están a tu disposición". ¿Es incluido o opcional? Confuso para guest.

#### Acceso de los huéspedes

```
Los huéspedes pueden disfrutar todas las áreas e instalaciones de las villas. El servicio de habitación se proporciona tres días de la semana, para estancias largas el cambio de sábanas es semanal..
```

#### Interacción con los huéspedes

```
Estamos disponibles en la propiedad para apoyarte en la planeación de excursiones y actividades. Nuestro conserje puede apoyar con lo que requieres antes y durante tu estancia. Resolvemos todas tus dudas cuantas veces sea necesario por medio de teléfono o whats una vez realizada la reservación..
```

#### Otros detalles a destacar

```
[EMPTY]
```

#### Cómo llegar (Directions)

Casi idéntico al kit Welcome RdM (lo que tiene sentido — Combinada incluye RdM). Sección 2 "Servicio cocina" dice **"está incluido en la renta"** (idéntico RdM). Diferencias vs RdM Directions:
- Sección 3 supermercados: "Mariscos 'Doña Lety'" en lugar de "Pescadería 'La More'" en posición 3
- Resto idéntico a RdM Directions

#### Método de llegada

```
Personal del edificio
```

🟡 **DIFFERENT** vs RdM/Morenas/Huerta (que usan "Caja de seguridad para llaves"). Tiene sentido para Combinada (más personal disponible).

#### Datos del wifi

```
Red: rincondelmar
Contraseña: rincondelmar
```

(Same as RdM and Huerta, NOT same as Morenas.)

#### Manual de la casa

```
[EMPTY — "Agregar detalles"]
```

🔴 **EMPTY** — gap a llenar.

#### Instrucciones para la salida

```
[EMPTY]
```

🔴 **EMPTY** — gap a llenar.

#### Reglas / metadata

- Llegada: 3:00 p.m.
- Salida: 11:00 a.m.
- Cancelación: Superestricta de 30 días
- Preferencias interacción: "Me gusta saludar en persona, pero fuera de eso, no convivo mucho."
- Ubicación: Nuevo Puerto Márquez 17, Llano Largo, Acapulco, Gro., Mexico
- Enlace personalizado: https://airbnb.mx/h/acapulco-dos-villas-pie-playa-chef-53-personas

---

### 1.4 Huerta Cocotera (1577678927412395161, room 637063)

#### Title

```
Título (ES, 40/50): Casa en huerta cocotera ¡a pie de playa!
Título (EN): NO existe EN version
Nombre interno (6/40): [private]
```

#### Description

```
Vive una experiencia única en nuestra huerta cocotera de 10,000 metros - una hectárea completa - a pie de playa - y tu propia palapa en la playa.

Disfruta amanecer rodado de palmeras de cocos, el mar justo enfrente de tu cabaña de lujo - y convive con nuestros animalitos!

La propiedad esta situada sobre la barra de Coyuca, una franja arenosa entre el mar y la laguna de Coyuca, un paraíso natural con enramadas y lugar para bañarse.

Conecta con la naturaleza en esta escapada inolvidable!
```

NOTA: NO menciona conteo reseñas (vs RdM/Morenas/Combinada que sí).

#### Tu propiedad

```
Nuestra cabaña esta construida de materiales regionales, finos muebles de madera de parota, una palapa exterior gigante y acabados en tonos claros. La propiedad es una antigua huerta cocotera que hemos convertido en un paraíso natural con plantas exóticas y animales. Tendrás tu palapa privada en la playa con dos hamacas, con el mar a tus pies - y vista a los 20 kilómetros de playa que nos rodea.

Si quieres, puedes pasearte con nuestros tres borregos y tres chivos y darles de comer, o ir a caminar a la playa con "la prieta", la perrita que hemos adoptado de la calle.

Disfruta la palapa exterior enorme, vivirás envuelto en la naturaleza!
- Cocina exterior completamente equipada
- Comedor para 12 personas
- Sala amplia con una hamaca king size
- De un lado un asador tipo argentino
- Y enfrente la alberca de borde infinito de 3 x 2 metros y 1.7 metros de profundidad

La distribución de las habitaciones que acomodan hasta 12 huéspedes:
- Una habitación con dos camas matrimoniales, un sofá cama matrimonial y uno individual, con aire acondicionado, televisión, closet y oficina completamente equipada
- Una habitación con una cama king size, un sofá y opcionalmente un colchón matrimonial, con aire acondicionado, cine en casa, closet amplio y un escritorio
- El baño esta completamente equipado, cuenta con agua caliente y se comparte entre las dos habitaciones.

Para tu conveniencia hay una tienda muy bien surtida a 100 metros, una lavandería justo al lado, y varias opciones de restaurantes tipo fonda en la cercanía. Hay un Oxxo a medio kilometro, una cajero automático a un kilometro, y un supermercado a 10 minutos.

Si tienes ganas de salir, Pie de la Cuesta, recién nombrado "Barrio mágico" esta a 10 minutos con algunos restaurantes y bares locales. Y en media hora estarás en la costera de Acapulco con sus restaurantes y bares.

Nuestro cuidador vive en un cuarto separado dentro de la huerta, el se preocupa de la alberca, la jardinería y los animales, pero igualmente te apoya en lo que puede. Una persona esta a cargo de la lavandería de 8am a 6pm, y puede ayudarte con el aseo diario..
```

#### Acceso de los huéspedes

```
Pueden usar toda la huerta, desde la avenida hasta el mar! 200 metros de larga y 50 metros de ancha!
```

#### Interacción con los huéspedes

```
Vivimos a media hora de la propiedad, pero siempre estaremos cerca para apoyarte con recomendaciones y resolvemos cualquier duda. Quieres rentar un yate o una lancha? Quieres salir a descubrir la zona y pasarte el día en algún lugar padre cercano? Necesitas ayuda en algo mas? Ahí estaremos para ayudarte ...
```

🟡 Diferencia: "Vivimos a media hora de la propiedad" — host NO está in-property como RdM/Morenas (donde Alex + equipo viven).

#### Otros detalles a destacar

```
La huerta esta situada sobre la barra de Coyuca en una franja arenosa entre el mar y la laguna de Coyuca. La zona es un paraíso natural donde podrás admirar flora y fauna de sus manglares. O sus enramadas que te invitan a disfrutar ricos platillos de mariscos y mucho lugar para bañarse. Hay tours en lancha para descubrir la laguna y la misteriosa "isla de las siete mujeres" - donde te espera hasta un cocodrilo. Si te gustan los deportes acuáticos puedes ponerte a practicar el esquí acuático - o un partido de vóley o futbol en la playa.
```

🟢 ÚNICO listing con contenido en "Otros detalles a destacar" (RdM/Morenas/Combinada = EMPTY).

#### Cómo llegar (Directions) — **~3,000 chars, MENOS extenso vs otros listings**

```
1️⃣ Les recomendamos usar el libramiento Acapulco - Zihuatanejo desde la ultima caseta "La venta" - probablemente Google Maps o Waze asi les indican. Se ahorran el macrotúnel y trafico de Acapulco. Es autopista hasta la costa, y unos 15 km por carretera. La ubicación de la casa: https://maps.app.goo.gl/3sY9HMb8HQ6rR2Sy9

2️⃣ Probablemente llegaran antes de las 6pm, y los recibimos en persona. Si llegan mas tarde encontraran la llave en una cajita de seguridad en la puerta, el código es "6720".

3️⃣ Wifi: La red se llama "rincondelmar", la contraseña es la misma "rincondelmar"

4️⃣ Si quieren planear sus compras desde antes de su llegada, aquí los supermercados más cercanos:
➡️ Bodega Aurrera, 10 minutos
➡️ Sam's Club, 35min
➡️ Pescadería "La More", a un kilómetro, camarones congelados y pescado fresco, servicio a domicilio: +52 744 551 5239
➡️ OXXO a 500 metros antes de la casa
➡️ Tienda "La Azucena" bastante bien surtida a 100 metros antes de la casa
Y tortillas a 50 metros de ahí

4️⃣ Para planear sus actividades:
➡️ Masajista Michel +52 744 221 7621 — puede ir a la huerta o tiene una palapa cerca
➡️ Contactos yates: Carlos Vinalay, Norma Rivera, Acascuba
➡️ Barra de Coyuca + Daribel restaurant
➡️ Tortuguero
➡️ Tres Marías esquí acuático

Bienvenidos!!
```

🔴 **Clave caja "6720" EXPLICITLY mentioned en Cómo llegar field** (en RdM/Morenas/Combinada NO está). Huerta tiene clave caja en estructura nativa AirBnB; otros no.

🟢 **DOES NOT mention $1,400 paquete eventos** (RdM Directions sí lo menciona, Morenas Directions también).

🟡 **NO menciona Combinada/RdM como alternativa** (RdM Directions linkea a sí mismo, Morenas linkea a RdM en sección "Necesitan más espacio").

#### Método de llegada

```
Caja de seguridad para llaves
```

#### Datos del wifi

```
Red: rincondelmar
Contraseña: rincondelmar
```

(Same as RdM and Combinada.)

#### Manual de la casa — ÚNICO listing con contenido DETALLADO

```
1️⃣ El proyector en la recamara principal se prende manualmente apretando el foco rojo en la parte de abajo. Después puedes conectarte seleccionando manualmente con el boton "source" a:
- Google Chromecast (celular) o por el
- Roku Stick (control negro)

2️⃣ El boiler estará apagado a su llegada, el agua del tinaco es mas que tibia normalmente. Si quieres prender el boiler, esta en el pasillo atrás de la cocina. Nada mas abre la llave de paso azul de PVC, y abajo del boiler hay un botón para prenderlo. En caso de que se acaben las pilas, son tamaño "D" y las venden en la tienda de en frente.

3️⃣ Hay tres tanques de gas, uno para la estufa, otro para el boiler, y uno lleno de reserva. En caso de que un tanque se acabe, les pedimos cambiarlo.

4️⃣ Para llegar a la playa vayan por la calle dentro de la huerta, entren a corral y encontraran un letrero que los lleva al camino hacia la playa. El acceso es por la derecha de la propiedad, y encontraran su palapa privada. Hay dos hamacas que pueden colgar en la palapa durante el día - les pedimos regresarlas a la casa antes de la noche.

5️⃣ Restaurantes cerca y servicios a casa:
➡️ El "Restaurancito" — restaurante medio km o entrega: https://maps.app.goo.gl/33tLC1dP6dXezAu37 +52 720 142 7045
➡️ Mariscos "Doña Lety" — un kilómetro, servicio a domicilio: +52 744 1460 216
➡️ "Bonita, su cocina" — medio km: https://maps.app.goo.gl/ADPV2Lw8ckKzFxat6
➡️ Baby's pizza: +52 744 438 2615

Y hay dos puestos del lado derecho de la huerta, de pollo y de antojitos, ambos bastante aceptables aunque no mis favoritos.

6️⃣ Y finalmente una palabra sobre los animalitos, nuestras estrellas. Todos los animales son muy mansos, no muerden, pueden acariciarlos.
➡️ A los chivos les encantan las tortillas, si les sobran. Más a los dos blancos, y al borrego macho. Pero tambien les dejaremos comida seca en un tambo blanco en la terraza. A sus hijos les va a gustar darles de comer, desde afuera de la cerca, o adentro.
➡️ La "prieta", la perrita que adoptamos de la calle los acompaña a la playa, le gusta meterse al mar. A veces anda en la calle, a veces en la casa si la dejan entrar. También les dejamos croquetas en otro tambo blanco si le quieren dar de comer. Si no les agrada o no sus mascotas no se llevan con ella, la pueden dejar afuera, no pasa nada..

Alguna otra recomendación que necesiten? Déjenme saber ..
```

🟢 **Excellent reference** — este Manual debería existir similar en RdM/Morenas/Combinada (donde está casi vacío). Modelo a replicar.

#### Instrucciones para la salida

```
Junta las toallas usadas
Apaga las luces los aparatos
Devuelve las llaves
```

🟢 ÚNICO listing con instrucciones (RdM/Morenas/Combinada = EMPTY).

#### Reglas / metadata

- Llegada: **3:00 p.m. - 8:00 p.m.** (BAR — diferente que otros que solo dicen "3:00 p.m.")
- Salida: 11:00 a.m.
- Capacidad: 12 huéspedes como máximo
- Cancelación: Firme (vs Estricta Morenas, Superestricta RdM/Combinada)
- Preferencias interacción: "No estaré presente, así que prefiero comunicarme a través de la app."
- Ubicación: Fuerza Aerea Mexicana 404, 39900, Acapulco de Juárez, Guerrero, Mexico
- Enlace personalizado: NO configurado

---

## 2. Cross-property analysis — inconsistencias detectadas

### 2.1 WiFi passwords

| Listing | Red | Contraseña |
|---|---|---|
| RdM | rincondelmar | rincondelmar |
| Morenas | **Rincondelmar1** | **Rincondelmar1** |
| Combinada | rincondelmar | rincondelmar |
| Huerta | rincondelmar | rincondelmar |

🔴 Morenas usa password distinto. Combinada (que incluye RdM + Morenas physically) declara solo el de RdM — guest que esté en lado Morenas necesita BOTH. **Falta documentar en Combinada Manual de la casa que hay 2 redes**.

### 2.2 Clave caja universal "6720"

- Solo Huerta lo tiene en field nativo AirBnB ("/arrival/directions" Cómo llegar)
- RdM/Morenas/Combinada lo tienen ÚNICAMENTE en templates T-1 archivados en mensajes
- Templates T-1 (`PROG: 50 - Un dia antes`) explicitamente dicen `La clave para abrir la caja es "6720"` para los 3

🔴 Mismo código "6720" universal en 4 propiedades — security risk si comprometido en cualquiera.

### 2.3 Servicio cocina (clarificación)

Resuelve la inconsistencia detectada en thread/36:

| Property | Modelo declarado en Directions field (source of truth operacional) |
|---|---|
| **RdM** | **INCLUIDO** en renta: "El servicio de nuestra chef, una cocinera y un mozo ya esta incluido en la renta!" |
| **Las Morenas** | **OPCIONAL** $1,000/noche (≤16 personas, dos cocineras) o $1,500/noche (>16, tres personas + mozo) |
| **Combinada** | **INCLUIDO** en renta: "ya esta incluido en la renta!" (idéntico RdM) |
| **Huerta** | **NO mencionado** — la cabaña no tiene servicio default |

🟡 Templates inquiry AirBnB:
- `0 - RdM completa` (ES): correct, dice "ya incluye"
- `2 - RdM english`: correct, "already includes"
- `3 - Morenas completa` (ES) line 137-145: 🔴 OMITE servicio (no menciona ni inclusión ni costo) — fix needed
- `3a Morenas english` line 159-188: 🔴 DICE "included" — WRONG, debe decir "optional $1,000/$1,500/day"
- `3b Morenas más 16`: 🔴 OMITE servicio — same as 3
- `4 - Dos Villas español` (Combinada): correct, dice "incluye"
- `5 - Dos Villas english`: correct, "already includes"
- `3d - Huerta`: ✅ correctamente no menciona (no aplica)

🔴 **Acción crítica Fase 1**: fix templates `3`, `3a`, `3b` Morenas inquiry para clarificar OPCIONAL $1,000/$1,500.

### 2.4 Equipo cocina (clarificación)

Resuelve inconsistencia detectada en thread/37 §1.2 (3.12):

| Source | Equipo declarado RdM |
|---|---|
| `0 - RdM completa` ES | "un chef, **una cocinera y un mozo**" |
| `2 - RdM english` | "a chef and **two cooks**" |
| `4 - Dos Villas español` (Combinada) | "un chef y **tres cocineros**" |
| Kit RdM | "nuestra chef, **una cocinera y un mozo**" |
| **AirBnB Description "Tu propiedad" RdM** (NEW) | **"Chef y cocinera"** (sin mozo) |
| **AirBnB Directions RdM** (NEW) | **"nuestra chef, una cocinera y un mozo"** |

🟡 Inconsistencia confirmada. Templates EN difieren del ES en mozo count + el listing "Tu propiedad" actual NO menciona mozo. Verdad probable: **1 chef + 1 cocinera + 1 mozo** (most frequent declaration). Templates EN + Combinada incorrectos.

### 2.5 Reseñas count

| Source | RdM | Morenas | Combinada | Huerta |
|---|---|---|---|---|
| AirBnB Description CURRENT | 168 | 128 | "más de 180" | (no menciona) |
| Templates inquiry | 150 | 150/190 | 190 | 300 |
| D1 reviews (sync 2026-05-12) | 50 (cap) | 50 (cap) | 50 (cap) | 17 |
| `p.rating.count` (content collection apps/web) | 167 | 129 | 89 | 17 |

🟡 AirBnB Descriptions están MÁS actualizadas que templates inquiry. Templates están desactualizados. apps/web content collection has different counts (89 Combinada vs "más de 180" AirBnB — apps/web is outdated).

Sources to align:
- AirBnB Description: 168 / 128 / "más de 180" / — (current truth)
- apps/web `properties/*.json`: 167 / 129 / 89 / 17 (close pero Combinada off)
- templates inquiry: 150 / 150-190 / 190 / 300 (mostly stale)

### 2.6 Cancelación policies

| Property | Política |
|---|---|
| RdM | Superestricta de 30 días |
| Morenas | Estricta |
| Combinada | Superestricta de 30 días |
| Huerta | Firme |

🟡 Asimetría inter-property. Posible decisión de negocio (Morenas + Huerta menos strict = más fácil llenar), pero NO mencionado en templates inquiry → guest puede sorprenderse al ver policy en checkout.

### 2.7 Direcciones físicas

- RdM: "C. Puerto Marques 17, Playa Hermosa Vicente Guerrero, 40989 San Nicolás de las Playas, Gro."
- Morenas: "C. Puerto Manzanillo 15, 40989 Gro." (less específico)
- Combinada: "Nuevo Puerto Márquez 17, Llano Largo, Acapulco, Gro."
- Huerta: "Fuerza Aerea Mexicana 404, 39900, Acapulco de Juárez, Guerrero"

🟡 Template `PROG: 50` T-1 RdM line 663 dice **"C. Puerto Huatulco 10 (esquina C Puerto Marquez 17), Col San Nicolás de las Playas, 40989 Coyuca de Benitez, Gro."** — esto declara dos calles distintas (Huatulco vs Marques). AirBnB field es **Marques**.

Posibilidad: la casa tiene dos accesos (uno por Huatulco, principal por Marques 17). T-1 template tiene info más útil que AirBnB field. **Decisión Alex needed**: cuál address es la actual para guests.

### 2.8 Llegada (check-in time)

| Property | Llegada |
|---|---|
| RdM | 3:00 p.m. |
| Morenas | 3:00 p.m. |
| Combinada | 3:00 p.m. |
| Huerta | **3:00 p.m. - 8:00 p.m.** (BAR) |

🟢 Huerta tiene ventana cerrada de check-in. Templates T-1 mencionan "después de las 3 PM" sin upper bound. Para Huerta hay que documentar la ventana.

### 2.9 Coanfitriones

- RdM + Morenas + Combinada: "Alexander Horn (dueño) + Karina Miranda Bartolo (Karina)" — confirmado Karina active
- Huerta: solo Alexander (NO Karina)

🟡 Karina solo en 3 propiedades. ¿Relación entre Karina y Huerta? ¿Necesita acceso?

---

## 3. Gaps + opportunities

### 3.1 Campos EMPTY que debemos llenar

| Field | RdM | Morenas | Combinada | Huerta |
|---|---|---|---|---|
| Otros detalles a destacar | 🔴 EMPTY | 🔴 EMPTY | 🔴 EMPTY | ✅ |
| Manual de la casa | 🟡 brief (3 frases) | 🟡 brief (2 frases) | 🔴 EMPTY | ✅ DETAILED 6 sec |
| Instrucciones para la salida | 🔴 EMPTY | 🔴 EMPTY | 🔴 EMPTY | ✅ 3 lines |

🔴 **3 de 4 propiedades tienen "Instrucciones para la salida" vacío** — pero AirBnB template `Instrucciones para la salida` (campo, no inquiry) probably falls back to default "¡Gracias por quedarte! La hora de salida es a las {Hora de salida}". Migrar contenido del template `PROG: 70 - Un dia antes de salida` aquí mejora UX.

🔴 **Combinada Manual de la casa vacío** — opportunity para describir cómo funciona el "Dos Villas" booking (acceso a ambas casas, key handoff, etc.).

### 3.2 EN versions missing

| Property | Title EN | Description EN |
|---|---|---|
| RdM | ✅ 47/50 chars | (not extracted) |
| Morenas | ✅ 29/50 chars | (not extracted) |
| Combinada | 🔴 missing | 🔴 missing |
| Huerta | 🔴 missing | 🔴 missing |

🟡 EN content cubre solo 50% propiedades. Para internacional bookings, gap.

### 3.3 Inconsistencias críticas accionables

**Quick wins Fase 1 (templates cleanup)**:

1. Fix `3 - Morenas` + `3a Morenas english` + `3b Morenas más 16` para clarificar servicio OPCIONAL $1,000/$1,500
2. Update reseñas count en templates inquiry (currently 150-300 stale)
3. Quitar footer interno `--> rincondelasmorenas / --> rincondelmar` (15+ templates)
4. Suavizar "inseguridad de Acapulco" → "alejado del bullicio" (5 templates)
5. Update paquete bodas $1,000 → $1,400 en templates `Paquete Bodas` ES + EN (templates current dicen $1,000, AirBnB Directions field dice $1,400)

**Medium effort fixes**:

6. Llenar Combinada Manual de la casa (currently EMPTY)
7. Llenar 3/4 Instrucciones para la salida (currently EMPTY)
8. Resolver dirección RdM (Marques vs Huatulco)
9. Documentar 2 WiFi networks en Combinada Manual
10. Decidir si clave caja "6720" mueve a AirBnB Check-in field para RdM/Morenas/Combinada (como Huerta) — y/o rotación per booking

**Long-term decisions Welcome Guide Fase 2**:

11. Replicar Huerta-style detailed Manual de la casa a RdM/Morenas (proyector, boiler, gas tanks, etc.)
12. Build /eventos.astro como source of truth $1,400 paquete bodas (vs templates desactualizados $1,000)
13. EN versions completar para Combinada + Huerta

---

## 4. Validación de hipótesis (WC thread/36 §7.2)

| Hipótesis WC | Verdad |
|---|---|
| **H1**: Description tiene draft 3,890 chars aplicado | ✅ Aplicado, pero MÁS corto (~500 chars). Field cap = 500. Sub-field "Tu propiedad" tiene el contenido extenso (~2000 chars RdM, ~2400 chars Morenas, ~3000 chars Huerta) |
| **H2**: House Manual probablemente vacío o desactualizado | ✅ Parcialmente true. RdM/Morenas: brief; Combinada: EMPTY; Huerta: DETAILED (excepción) |
| **H3**: Check-in Instructions tiene dirección + clave caja, Alex repite en T-1 | 🟡 PARCIAL: Huerta sí ("código es 6720" en Directions field). RdM/Morenas/Combinada NO tienen clave caja en field — solo en T-1 templates archivados en messages |
| **H4**: House Rules probablemente tiene basics pero falta granularidad | (URL 404, no verifiable) |
| **H5**: "The Space" y "Guest Access" desactualizados, amenidades stale | (URL 404, content now under /details/description) — la sub-section "Tu propiedad" para RdM/Morenas está bastante DETALLADA y current. Combinada short |

---

## 5. Next steps recomendados

### Inmediato

1. **Templates Fase 1 cleanup** ahora puede ejecutarse con info accurate (post Alex Q&A on servicio Morenas + precio bodas)
2. **Combinada Manual de la casa** — Alex llena el field (5-10 min) o CC drafta para approval
3. **EN versions** — defer hasta Welcome Guide Fase 2 (mismo CC time investment)

### Welcome Guide Fase 2 informed by this inventory

Lo que ya existe en AirBnB y NO necesita re-escribirse:
- ✅ Description ES (500 chars hooks per property — current)
- ✅ Tu propiedad ES (1500-2500 chars per property — current, RdM/Morenas/Huerta DETAILED)
- ✅ Cómo llegar (5,000 chars Welcome Kit — vive en 3 listings, ausente Huerta)

Lo que SÍ falta crear / mejorar:
- 🔴 Welcome Guide page propio `/welcome/{property}` (web hosted, full structure)
- 🔴 Combinada Manual de la casa + Instrucciones salida
- 🔴 RdM/Morenas/Combinada Instrucciones salida (defer si Welcome Guide cubre)
- 🟡 Huerta Welcome Kit (current Directions field es 3K chars vs RdM/Morenas 5K — opportunity)
- 🟡 EN versions todo

### Pattern para Welcome Guide content

Use Huerta Manual de la casa como **plantilla** para las otras propiedades:
- 6 sections numeradas con emojis
- Includes: proyector/TV, boiler/agua caliente, gas tanks, acceso playa, restaurantes cercanos, animalitos/peculiaridades

Replicar a:
- RdM: chef Celene info + cocina interior, alberca infinita, palapa, sala audio
- Morenas: chef opcional pricing, alberca grande, terraza
- Combinada: ambas WiFi networks, key handoff workflow

---

**Status**: Inventario completo de campos AirBnB. ~25K chars extraídos. Ready para input a Fase 1 cleanup + Fase 2 Welcome Guide.

— Claude Code (CLI) via Chrome MCP, 2026-05-13
