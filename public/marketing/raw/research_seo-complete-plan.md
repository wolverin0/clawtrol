# Plan SEO Completo (Implementación + Investigación) — Futura Sistemas (Argentina)

**Fecha:** 2026-02-09  
**Mercado:** Argentina (es-AR), ARS, normativa AFIP/ARCA  
**Productos:** FuturaDelivery, FuturaFitness, FuturaCRM + Servicios (IA / automatización)  
**Estado actual:** 3 SPAs Vite/React con visibilidad orgánica casi nula (renderizado cliente, sin metadatos, sin schema, sin sitemap, sin blog, sin Search Console).

---

## 0) Resumen ejecutivo (qué hacer primero y por qué)

### El problema raíz
- Los 3 sitios son **SPAs (CSR)** y hoy presentan el patrón típico: el HTML inicial llega “vacío” y el contenido se genera en el cliente con JS. Esto **reduce drásticamente indexabilidad** y la capacidad de rankear para keywords no-branded.

### Objetivos (90 días)
1. **Indexabilidad**: pasar de “casi invisible” a “rastreable e indexable” (SSR/SSG + sitemap + robots + canonical + metadatos + schema + GSC).
2. **Captura de demanda**: atacar keywords con intención alta por producto (software/plataforma/sistema/para… + AFIP/pos/stock + delivery sin comisión + app para entrenadores).
3. **Autoridad temática**: construir 3 clusters por producto (pilar + soporte) + comparativas + FAQs.
4. **Leads**: optimizar landings para demo/WhatsApp/cotización y medir con analytics.

### Prioridad recomendada
1) **FuturaCRM** (mayor LTV y demanda estable en Argentina por AFIP + POS + stock + MercadoLibre + e-commerce).  
2) **FuturaDelivery** (dolor claro: comisiones 25–35% en plataformas, más fácil crear narrativa “0% comisión”).  
3) **FuturaFitness** (demanda existe pero más fragmentada; fuerte oportunidad en “software para entrenadores” + “planes de entrenamiento” + “nutrición” + “IA”).

---

## 1) Fundamentos: Arquitectura SEO para 3 productos + marca

### 1.1 Estructura de dominios (recomendación)
Hoy se usan subdominios Vercel tipo `*.vercel.app`.

**Recomendación:** migrar a dominios propios (ideal) con estructura:
- `futurasistemas.com.ar` (sitio corporativo)
- `futurasistemas.com.ar/delivery/` (FuturaDelivery) **o** `futuradelivery.com.ar`
- `futurasistemas.com.ar/fitness/` (FuturaFitness) **o** `futurafitness.com.ar`
- `futurasistemas.com.ar/crm/` (FuturaCRM) **o** `futuracrm.com.ar`

**Decisión estratégica:**
- Si quieren crecer autoridad de marca rápido: **1 dominio** (subcarpetas) es mejor para consolidar backlinks.
- Si quieren posicionamiento “producto first”: dominios separados también sirve, pero exige 3x esfuerzo de autoridad.

### 1.2 Estructura de URLs (limpia y escalable)
Para cada producto:
- `/` (home producto)
- `/precios/`
- `/funcionalidades/`
- `/integraciones/` (MercadoPago, MercadoLibre, WhatsApp, AFIP, TiendaNube, etc.)
- `/industrias/` (restaurantes, gimnasios, comercios, pymes, profesionales)
- `/recursos/` (blog + guías)
- `/comparativas/` (X vs Y)
- `/casos/` (casos de éxito)
- `/faq/` (FAQs “rich results”)

---

## 2) Investigación de keywords (Argentina, es-AR) — por producto + servicios

> Nota metodológica: sin acceso a herramientas pagas (Ahrefs/SEMrush) para volumen exacto, se usa **estimación por intención** + señales de SERP (autocompletado, resultados dominantes, tipo de páginas de competidores y contenido que aparece). El objetivo es un **plan accionable**: clusters + intención + tipos de páginas + ángulos.

### Leyenda de intención
- **T (Transaccional)**: busca comprar / contratar / precio / demo / software
- **C (Comercial-investigación)**: comparativas / mejores / alternativas
- **I (Informacional)**: cómo hacer / guía / requisitos / beneficios
- **N (Navegacional)**: marca/competidor

---

# 2A) FuturaCRM — Keywords + clusters (AFIP + stock + POS + e-commerce + MercadoLibre)

## 2A.1 Keyword universe (30+ primarias) — intención estimada
1. **software de facturación electrónica AFIP** (T)
2. **sistema de facturación AFIP** (T)
3. **facturación electrónica Argentina software** (T)
4. **software para hacer facturas A B C** (T)
5. **programa para facturar monotributo** (T)
6. **software para monotributistas facturación** (T)
7. **software para pymes Argentina** (T)
8. **sistema de gestión para pymes** (T)
9. **ERP para pymes Argentina** (C/T)
10. **sistema de gestión comercial** (T)
11. **software de stock e inventario** (T)
12. **control de stock en la nube** (T)
13. **software punto de venta POS Argentina** (T)
14. **sistema POS para comercio** (T)
15. **software para comercio minorista** (T)
16. **sistema de caja para negocio** (T)
17. **facturación + stock + ventas** (T)
18. **software de gestión con MercadoLibre** (T)
19. **integración MercadoLibre stock y facturación** (T)
20. **facturar ventas de MercadoLibre** (I/T)
21. **software para TiendaNube facturación AFIP** (T)
22. **software para e-commerce con facturación** (T)
23. **CRM para pymes Argentina** (C/T)
24. **software de clientes y ventas** (T)
25. **gestión de compras y proveedores** (T)
26. **remitos y facturas software** (T)
27. **presupuestos y facturación** (T)
28. **sistema multi sucursal stock** (T)
29. **sistema de gestión con lector código de barras** (T)
30. **programa de facturación online** (T)
31. **software contable en la nube Argentina** (C/T)
32. **libro IVA digital / IVA simple Portal IVA software** (I/C)
33. **facturación para responsables inscriptos** (T)
34. **facturación para monotributo + control de stock** (T)
35. **sistema para emitir notas de crédito AFIP** (T)

### LSI / semánticas (variaciones)
- “**sistema de gestión**”, “**sistema administrativo**”, “**ERP**”, “**software de gestión integral**”
- “**factura electrónica**”, “**CAE**”, “**punto de venta**”, “**comprobantes en línea**”
- “**inventario**”, “**stock mínimo**”, “**kardex**”, “**código de barras**”
- “**POS**”, “**caja**”, “**ventas mostrador**”, “**turnos de caja**”
- “**Mercado Envíos**”, “**MercadoPago**”, “**MercadoShops**”, “**Tiendanube**”

## 2A.2 Long-tail (20+) — muy accionables para landings / posts
1. software de facturación electrónica AFIP **para monotributistas**
2. software para hacer **factura C** monotributo en la nube
3. software para emitir **factura A** responsable inscripto
4. sistema de facturación con **punto de venta** y **control de stock**
5. programa para facturar con **lector de códigos de barras**
6. software para kiosco con **caja y stock**
7. software para ferretería con **stock por variantes**
8. software para indumentaria con **talles y colores**
9. sistema para **multisucursal** con stock centralizado
10. software para integrar **MercadoLibre** y actualizar stock automáticamente
11. cómo facturar ventas de MercadoLibre **automáticamente**
12. cómo hacer **nota de crédito** por devolución MercadoLibre
13. software para TiendaNube que **facture automáticamente AFIP**
14. sistema de gestión con **webshop** integrado
15. sistema de ventas con **cuentas corrientes clientes/proveedores**
16. software para controlar stock con **alerta de mínimo**
17. software para **presupuestos** que se convierten en factura
18. sistema para **remitos** y seguimiento de entrega
19. software para comercio con **lista de precios** y descuentos
20. sistema de gestión para pymes Argentina con **CRM + facturación + stock**
21. software para “facturación electrónica AFIP” **sin entrar a AFIP**
22. cómo conectar AFIP con mi sistema de facturación (API)

## 2A.3 Comparativas (10+) — páginas “/comparativas/”
1. **FuturaCRM vs Colppy**
2. **FuturaCRM vs Xubio**
3. **FuturaCRM vs Calipso**
4. **Colppy vs Xubio** (capturar intención existente)
5. **Alegra vs Xubio**
6. **Contabilium vs Xubio**
7. **TusFacturasAPP vs Xubio**
8. **software AFIP gratis vs software de gestión**
9. **facturación electrónica AFIP: portal vs sistema**
10. **ERP para pymes: Odoo vs software argentino**

## 2A.4 Problema / “cómo hacer” (10+) — posts guías + FAQ
1. **cómo hacer factura electrónica AFIP paso a paso**
2. **cómo habilitar punto de venta para factura electrónica**
3. **cómo emitir factura A B C** (diferencias)
4. **cómo hacer nota de crédito AFIP**
5. **cómo llevar control de stock** en un negocio
6. **cómo hacer inventario** de mercadería
7. **cómo integrar MercadoLibre con stock y facturación**
8. **cómo facturar ventas de TiendaNube**
9. **cómo hacer remitos** y cuándo conviene
10. **cómo elegir un sistema de gestión para pymes**

## 2A.5 Keywords de competidores (qué suelen atacar y por qué)
### Colppy
- Ataca “**software contable**”, “**gestión**”, “**facturación**”, “**pymes**”, y páginas de producto/planes.
- SERP típica: páginas de **producto + pricing**, artículos “cómo hacer X” y comparativas en terceros.

### Xubio
- Fuerte en “**contabilidad en la nube**”, “**facturación electrónica AFIP**”, “**Libro IVA / IVA digital**” y **integraciones** (ej. TiendaNube) según su presencia como integración en marketplaces.

### Calipso
- Más enterprise: “**ERP**”, “**BPM**”, “**facturación**”, “**gestión empresarial**” y “solución modular”.

### Otros SERP players locales (derivados de investigación)
- TusFacturasAPP (facturación AFIP + stock) y sitios informativos como Contagram o TiendaNube (educación de facturas y tipos A/B/C).

---

# 2B) FuturaDelivery — Keywords + clusters (0% comisión, pedidos directos, menú QR)

## 2B.1 Primarias (30+)
1. **sistema de pedidos online para restaurantes** (T)
2. **plataforma de delivery para restaurantes** (T)
3. **delivery sin comisiones** (C/T)
4. **app de delivery para restaurantes sin comisión** (T)
5. **alternativas a PedidosYa para restaurantes** (C)
6. **alternativas a Rappi para restaurantes** (C)
7. **cómo vender sin PedidosYa** (I/C)
8. **comisiones PedidosYa restaurantes** (I)
9. **comisiones Rappi restaurantes** (I)
10. **sistema de pedidos por WhatsApp restaurante** (T)
11. **pedidos online con WhatsApp** (T)
12. **menú digital QR para restaurantes** (T)
13. **menú QR gratis** (I/C)
14. **carta digital QR** (T)
15. **menú digital con precios actualizables** (T)
16. **sistema de take away** (T)
17. **sistema de reservas restaurante** (T)
18. **software para delivery propio** (T)
19. **tienda online para restaurante** (T)
20. **sistema para recibir pedidos en cocina** (T)
21. **gestión de pedidos restaurante** (T)
22. **plataforma de pedidos directos** (T)
23. **web para restaurante con pedidos online** (T)
24. **bot de WhatsApp para pedidos** (T)
25. **catálogo WhatsApp restaurante** (T)
26. **promociones y cupones para pedidos online** (I/T)
27. **fidelización clientes restaurante** (I/T)
28. **programa de puntos restaurante** (I/T)
29. **integración MercadoPago pedidos restaurante** (T)
30. **QR menú + pago** (T)
31. **cómo aumentar ventas delivery** (I)
32. **cocina fantasma / dark kitchen** (I/C)
33. **software para dark kitchen** (T)
34. **pedido online sin marketplace** (C/T)
35. **pedido directo restaurante** (T)

### LSI / semánticas
- “pedidos directos”, “canal propio”, “sin intermediarios”, “0% comisión”, “suscripción mensual”, “menú QR”, “carta digital”, “take away”, “delivery propio”, “WhatsApp ordering”, “Google Maps botón pedir”.

## 2B.2 Long-tail (20+)
1. plataforma de delivery **0% comisión** para restaurantes Argentina
2. sistema de pedidos online para restaurantes **con WhatsApp**
3. menú QR para restaurante **con fotos y categorías**
4. menú digital QR **que se actualiza sin reimprimir**
5. sistema de pedidos para restaurante **con pagos MercadoPago**
6. link de pedidos para Instagram **para restaurante**
7. cómo crear pedidos online para mi restaurante **sin apps de delivery**
8. cómo reducir comisiones de PedidosYa y Rappi
9. alternativas a PedidosYa **para pizzerías**
10. sistema de pedidos online para **empanadas**
11. sistema de delivery propio para **heladerías**
12. sistema de pedidos por WhatsApp **con respuestas automáticas**
13. menú QR multi-idioma para turismo
14. panel de administración pedidos restaurante en tiempo real
15. cómo aumentar ticket promedio en pedidos online
16. sistema de cupones y combos para delivery
17. cómo fidelizar clientes con pedidos directos
18. sistema de pedidos con zona de delivery y costo de envío
19. herramienta para imprimir comandas / cocina
20. plataforma de suscripción mensual para pedidos restaurante

## 2B.3 Comparativas (10+)
1. **FuturaDelivery vs PedidosYa** (modelo: comisión vs suscripción/0%)
2. **FuturaDelivery vs Rappi**
3. **FuturaDelivery vs Meniu** (menú QR + gestión)
4. **FuturaDelivery vs RAY** (0 comisión)
5. **FuturaDelivery vs Pedidosfree**
6. **Meniu vs QueRestó** (capturar búsquedas de menú QR)
7. **menú QR gratis vs menú QR premium**
8. **delivery propio vs delivery por apps**
9. **WhatsApp pedidos vs app propia**
10. **dark kitchen vs restaurante tradicional (para delivery)**

## 2B.4 Problema / “cómo hacer” (10+)
1. cómo reducir comisiones de delivery en Argentina
2. cómo vender por WhatsApp en un restaurante
3. cómo hacer un menú QR para mi restaurante
4. cómo aumentar pedidos online sin PedidosYa
5. cómo calcular costo de envío para delivery
6. cómo armar combos para subir ticket promedio
7. cómo gestionar pedidos en cocina sin errores
8. cómo fidelizar clientes con cupones y puntos
9. cómo captar pedidos desde Google Maps
10. cómo abrir una dark kitchen en Argentina (guía)

## 2B.5 Competidores y keywords que trabajan
- **PedidosYa / Rappi (marketplaces)**: rankean fuerte por marca (N) y por “delivery”, pero para restaurantes su contenido suele ser de socios/partners.
- Alternativas detectadas en búsqueda: **RAY** (0 comisión), **Meniu** (menú QR), **RestoSimple**, **Pedidosfree**, y múltiples “menú QR gratis”.
- Oportunidad: el SERP de “menú digital QR gratis” está lleno de soluciones simples: faltan páginas que conecten **menú QR + pedidos + pagos + fidelización + métricas** con foco en rentabilidad.

---

# 2C) FuturaFitness — Keywords + clusters (software para entrenadores, IA rutinas/nutrición, gamificación)

## 2C.1 Primarias (30+)
1. **app para entrenadores personales** (T)
2. **software para personal trainer** (T)
3. **plataforma para entrenadores online** (T)
4. **gestión de clientes personal trainer** (T)
5. **app para crear rutinas de entrenamiento** (T)
6. **generador de rutinas** (I/T)
7. **app para planes de entrenamiento** (T)
8. **app para seguimiento de progreso gimnasio** (T)
9. **app para registro de entrenamientos** (T)
10. **app de nutrición para entrenadores** (T)
11. **crear plan nutricional personalizado** (I/T)
12. **IA para crear rutinas de gimnasio** (I/T)
13. **inteligencia artificial fitness** (I/C)
14. **app fitness con inteligencia artificial** (C/T)
15. **app para dieta y macros** (I/T)
16. **calculadora de macros** (I)
17. **app para medir adherencia entrenamiento** (I/T)
18. **gamificación en fitness** (I/C)
19. **retención de clientes gimnasio** (I/T)
20. **cómo fidelizar clientes personal trainer** (I)
21. **app para vender planes de entrenamiento** (T)
22. **cobrar online personal trainer** (I/T)
23. **app para clases online entrenamiento** (T)
24. **rutinas para hipertrofia app** (I/T)
25. **rutinas para bajar de peso app** (I/T)
26. **app para seguimiento de medidas corporales** (T)
27. **software para gimnasio vs app para entrenadores** (C)
28. **entrenamiento online personalizado** (I/C)
29. **planificación de entrenamiento** (I)
30. **app para coaching fitness** (T)
31. **app para entrenadores con chat** (T)
32. **app para hábitos saludables** (I/T)
33. **app con IA para nutrición** (C/T)
34. **crear rutina en segundos** (T)
35. **mejor app para entrenadores personales** (C)

### LSI / semánticas
- “coach”, “alumnos”, “seguimiento”, “progresiones”, “RPE”, “ficha”, “check-in”, “hábitos”, “onboarding”, “mensajería”, “planes”, “rutinas”, “nutrición”, “macros”, “gamificación”, “desafíos”.

## 2C.2 Long-tail (20+)
1. software para personal trainer **para gestionar clientes y pagos**
2. app para entrenadores con **rutinas y nutrición**
3. app para crear rutinas **con inteligencia artificial**
4. generador de rutinas para gimnasio **según objetivo**
5. app para plan nutricional **según macros y calorías**
6. app para entrenadores con **gamificación y desafíos**
7. cómo hacer seguimiento de progreso de alumnos online
8. cómo armar plan de entrenamiento para principiantes
9. cómo armar rutina de hipertrofia 4 días
10. cómo hacer periodización entrenamiento fuerza
11. software para entrenadores que **envía rutinas por app**
12. app para personal trainer con **chat y recordatorios**
13. app para entrenadores que mejora **retención** de clientes
14. sistema para entrenadores con **evaluaciones** y medidas
15. app para coaching fitness **multi cliente**
16. software para personal trainer en español
17. app para entrenadores con **biblioteca de ejercicios**
18. app para entrenadores con **formularios PAR-Q**
19. app para armar dieta para bajar de peso y sostener
20. app para entrenadores con **panel** de cumplimiento

## 2C.3 Comparativas (10+)
1. **FuturaFitness vs Trainerize**
2. **FuturaFitness vs Hevy Coach**
3. **FuturaFitness vs Smartgym**
4. **Trainerize vs Hevy** (capturar demanda existente)
5. **TrueCoach vs Trainerize**
6. **Harbiz vs Trainerize**
7. **Trainingym vs software para personal trainers**
8. **Hevy vs app de registro de entrenamiento**
9. **Fitbod vs app para entrenadores**
10. **app con IA vs rutina manual (Excel/Google Sheets)**

## 2C.4 Problema / “cómo hacer” (10+)
1. cómo crear una rutina personalizada para un alumno
2. cómo hacer un plan nutricional para bajar de peso
3. cómo calcular macros para ganar músculo
4. cómo retener clientes como personal trainer
5. cómo vender planes de entrenamiento online
6. cómo hacer seguimiento del progreso de un cliente
7. cómo hacer evaluación inicial para entrenador personal
8. cómo evitar estancamiento en hipertrofia (ajustes)
9. cómo usar IA para crear rutinas (pros/contras)
10. cómo gamificar un programa fitness

## 2C.5 Competidores y keywords que suelen dominar
- **Trainerize / TrueCoach / Hevy Coach / Harbiz / Trainingym**: páginas de producto + pricing + features + comparativas.
- SERP en español para “software personal trainer” suele estar dominado por:
  - directorios (Capterra, GetApp, comparasoftware)
  - páginas de vendors (features)
  - contenido educativo de “fidelización/retención” (blogs fitness B2B)
- Oportunidad: “IA para rutinas + nutrición” y “gamificación” aún es menos competido en es-AR con enfoque para entrenadores (no B2C).

---

# 2D) Servicios Futura Sistemas — IA, chatbots, asistentes, automatización, videovigilancia

## 2D.1 Primarias (30+)
1. **chatbot para empresas Argentina** (T)
2. **chatbot WhatsApp para negocios** (T)
3. **automatización de WhatsApp Business** (T)
4. **asistente virtual IA para empresas** (T)
5. **agente de IA para atención al cliente** (T)
6. **automatización de procesos empresas** (T)
7. **automatización procesos pymes Argentina** (T)
8. **RPA Argentina** (C/T)
9. **integración de IA en empresas** (C/T)
10. **implementación chatbots** (T)
11. **chatbot para ecommerce** (T)
12. **chatbot para reservas** (T)
13. **chatbot para cobranzas** (T)
14. **chatbot para inmobiliaria** (T)
15. **automatización de ventas** (T)
16. **automatización de soporte** (T)
17. **integración CRM + WhatsApp** (T)
18. **integración API WhatsApp** (T)
19. **asistente virtual 24/7** (T)
20. **automatización con n8n** (I/T)
21. **automatización con Make/Zapier** (I/T)
22. **bot con inteligencia artificial en web** (T)
23. **call center con IA** (C/T)
24. **visión artificial seguridad** (C/T)
25. **videovigilancia con inteligencia artificial** (T)
26. **detección de intrusos por IA** (T)
27. **reconocimiento facial empresas Argentina** (C/T)
28. **cámaras con analítica de video** (T)
29. **automatización de facturación** (T)
30. **automatización de reportes** (I/T)

### Long-tail (20+)
1. chatbot WhatsApp para empresas con atención 24/7
2. asistente virtual para tomar pedidos por WhatsApp
3. chatbot para turnos y reservas automático
4. automatización de cobranzas por WhatsApp con recordatorios
5. integración de chatbot con CRM y Google Sheets
6. automatización de procesos administrativos con IA
7. RPA para carga de facturas y conciliación
8. automatización de respuestas frecuentes en soporte
9. agente IA para e-commerce que recomienda productos
10. implementación de chatbots con conocimiento de documentos (FAQ)
11. videovigilancia con IA para detectar movimientos sospechosos
12. analítica de video para comercios (conteo personas)
13. detección de EPP en industria con visión artificial
14. automatización de seguimiento de leads desde formularios
15. automatización de tickets y derivación a humano
16. integración WhatsApp API con sistemas internos
17. chatbot para inmobiliaria captura leads
18. bot para clínicas: turnos, recordatorios, preconsulta
19. automatización de procesos con n8n en servidores propios
20. consultoría de IA para pymes en Argentina

### Comparativas (10+)
1. chatbot a medida vs plataforma (ManyChat / Botmaker / etc.)
2. n8n vs Zapier vs Make
3. WhatsApp API oficial vs WhatsApp Business manual
4. asistente IA vs chatbot tradicional
5. RPA vs automatización con APIs
6. visión artificial on-premise vs cloud
7. agente IA con RAG vs FAQ fijo
8. call center humano vs IA híbrida
9. chatbot para ventas vs chatbot para soporte
10. analítica de video vs CCTV tradicional

### Problema / “cómo hacer” (10+)
1. cómo automatizar WhatsApp Business sin perder clientes
2. cómo implementar un chatbot en la web
3. cómo medir ROI de un chatbot
4. cómo automatizar seguimiento de leads
5. cómo integrar WhatsApp con CRM
6. cómo crear workflows con n8n
7. cómo automatizar facturación y reportes
8. cómo reducir tiempos de respuesta en soporte
9. cómo usar IA en seguridad con cámaras
10. cómo elegir proveedor de IA en Argentina

---

## 3) Análisis SEO de competidores (SERP Argentina) — patrones y brechas

### 3.1 Qué tipo de páginas dominan (por vertical)

#### Vertical “AFIP / facturación / gestión” (CRM)
**Dominan:**
- Landings de software (pricing/features) + páginas de integraciones.
- Contenido educativo evergreen: “cómo emitir factura”, “tipos de factura A/B/C”, “punto de venta”, “Libro IVA/IVA Simple”.
- Marketplaces / directorios: comparasoftware, Capterra, GetApp.

**Brecha explotable:**
- Pocas páginas combinan **AFIP + MercadoLibre + stock + POS + tienda online** en un mismo discurso orientado a “negocio real”.
- Mucho contenido se centra en contadores; falta un ángulo más “operativo” (dueño de comercio) con guías prácticas.

#### Vertical “delivery restaurantes” (Delivery)
**Dominan:**
- Marketplaces y notas (comisiones, comparativas) + soluciones de menú QR.
- Contenido de “menú digital QR gratis” con landings sencillas.

**Brecha explotable:**
- Falta de enfoque en **rentabilidad**: cuánto te cuesta comisión vs suscripción (calculadoras), captura de datos de clientes, CRM de repetición.

#### Vertical “software personal trainer” (Fitness)
**Dominan:**
- Vendors internacionales (en inglés/español), comparativas y directorios.
- Contenido B2B sobre retención/gamificación.

**Brecha explotable:**
- Contenido en es-AR orientado a entrenadores del mercado local (cobros, moneda, WhatsApp, hábitos). 
- Diferenciación por **IA (Gemini)** aplicada al flujo del entrenador.

### 3.2 Contenidos que conviene replicar (mejorados)
- “Guías paso a paso” con capturas y checklist.
- “Plantillas descargables” (Excel/Google Sheets) para inventario, rutina, plan nutricional, cálculo de comisión.
- “Calculadoras” (comisión delivery; macros; costo de envío; margen por producto).
- “Comparativas honestas” con tabla, pros/contras y recomendación por caso.

### 3.3 Contenidos que conviene NO copiar (o copiar distinto)
- Posts genéricos sin intención (“qué es un ERP”) sin enfoque local.
- Textos largos sin CTA y sin estructura (pierden conversión).

---

## 4) Plan técnico SEO para SPAs Vite/React (FuturaDelivery/Fitness/CRM)

### 4.1 Objetivo técnico
Lograr:
- **HTML pre-renderizado** por ruta (contenido visible sin JS)
- Metadatos por página (title/description/OG/Twitter)
- Sitemap XML y robots.txt
- Canonicals correctos
- Schema JSON-LD
- Performance (Core Web Vitals)

### 4.2 Estrategias viables (de menor a mayor esfuerzo)

#### Opción A — **Pre-render (SSG) con rutas conocidas** (recomendado para marketing)
Ideal cuando:
- páginas “marketing” son estáticas o cambian poco.

Implementación típica:
- usar `vite-ssg` o equivalente para generar HTML por ruta
- mantener la app como SPA para panel interno (si existiera)

Pros:
- rápido, barato, muy SEO-friendly

Contras:
- contenido muy dinámico requiere rebuild

#### Opción B — **SSR con Vite**
Ideal cuando:
- hay contenido dinámico (ej. blog, casos, integraciones) o personalización.

Pros:
- HTML siempre actualizado

Contras:
- más infraestructura (server runtime)

#### Opción C — Dynamic Rendering (cloaking “aceptado” para bots)
- Detectar bots y servir versión pre-renderizada.
- Hoy Google tolera dynamic rendering para casos específicos, pero es “puente”, no ideal.

**Recomendación:** A o B. Para 60 días: **SSG** para marketing + blog (con MDX/CMS) y luego evolucionar.

### 4.3 Checklist de implementación técnica (por sitio)

#### 4.3.1 Head tags por página
- `<title>` único (55–60 chars aprox)
- `<meta name="description">` único (140–160)
- `<link rel="canonical">`
- Open Graph + Twitter
- Hreflang (si solo es es-AR, se puede omitir o usar es-AR)

**Librerías comunes en React:** `react-helmet-async`.

#### 4.3.2 Robots.txt
- permitir rastreo de páginas públicas
- bloquear rutas internas (si existieran): `/app/`, `/admin/`, etc.

#### 4.3.3 Sitemap.xml
- incluir todas las URLs indexables
- auto-generar en build

#### 4.3.4 Canonicalización y parámetros
- evitar duplicados (UTM)

#### 4.3.5 Indexación
- Google Search Console: propiedad por dominio + sitemaps
- Bing Webmaster Tools (bonus)

#### 4.3.6 Performance
- imágenes: WebP/AVIF
- lazy load
- code splitting
- minimizar JS

### 4.4 Plantillas de metadatos (listas para usar)

#### Plantilla Home Producto
- **Title:** `[Producto] | [beneficio principal] para [ICP] en Argentina`
- **Description:** `Gestioná [tarea] con [Producto]: [2-3 diferenciales]. Integración [local]. Pedí demo.`

Ejemplos:
- FuturaCRM: `FuturaCRM | Facturación AFIP + Stock + POS + MercadoLibre`
- FuturaDelivery: `FuturaDelivery | Pedidos directos 0% comisión + Menú QR`
- FuturaFitness: `FuturaFitness | App para entrenadores con rutinas y nutrición con IA`

#### Plantilla Post Blog
- Title: `Cómo [hacer X] en Argentina (guía 2026)`
- Description: `Paso a paso + errores comunes + checklist + herramienta.`

### 4.5 Schema (JSON-LD) — templates

> Implementar por página, no “uno global para todo”. Validar en Rich Results Test.

#### 4.5.1 Organization (site-wide)
```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Futura Sistemas",
  "url": "https://futurasistemas.com.ar",
  "logo": "https://futurasistemas.com.ar/logo.png",
  "sameAs": [
    "https://www.instagram.com/futurasistemas.com.ar/"
  ]
}
```

#### 4.5.2 Software Product (por producto) — usar **Product** + **SoftwareApplication/WebApplication**

**FuturaCRM (ejemplo):**
```json
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "FuturaCRM",
  "description": "Sistema de gestión para pymes en Argentina: facturación electrónica AFIP, stock, POS, webshop, CRM e integración con MercadoLibre.",
  "brand": { "@type": "Brand", "name": "Futura Sistemas" },
  "offers": {
    "@type": "Offer",
    "priceCurrency": "ARS",
    "availability": "https://schema.org/InStock",
    "url": "https://futurasistemas.com.ar/crm/precios/"
  }
}
```

**FuturaDelivery (ejemplo):**
```json
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "FuturaDelivery",
  "applicationCategory": "BusinessApplication",
  "operatingSystem": "Web",
  "description": "Plataforma de pedidos directos para restaurantes: 0% comisión, menú QR, pedidos por WhatsApp y pagos.",
  "offers": {
    "@type": "Offer",
    "priceCurrency": "ARS",
    "availability": "https://schema.org/InStock",
    "url": "https://futurasistemas.com.ar/delivery/precios/"
  }
}
```

**FuturaFitness (ejemplo):**
```json
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "FuturaFitness",
  "applicationCategory": "HealthApplication",
  "operatingSystem": "Web",
  "description": "App para entrenadores personales: rutinas y planes nutricionales generados con IA, seguimiento y gamificación.",
  "offers": {
    "@type": "Offer",
    "priceCurrency": "ARS",
    "availability": "https://schema.org/InStock",
    "url": "https://futurasistemas.com.ar/fitness/precios/"
  }
}
```

#### 4.5.3 FAQPage (para landings y páginas FAQ)
```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "¿FuturaCRM sirve para monotributistas?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Sí. Podés emitir comprobantes tipo C, gestionar clientes, stock y caja según tu operatoria."
      }
    }
  ]
}
```

#### 4.5.4 Article / BlogPosting (posts)
```json
{
  "@context": "https://schema.org",
  "@type": "BlogPosting",
  "headline": "Cómo emitir factura electrónica en AFIP paso a paso (Guía 2026)",
  "datePublished": "2026-02-09",
  "author": {"@type": "Organization", "name": "Futura Sistemas"},
  "mainEntityOfPage": {"@type": "WebPage", "@id": "https://futurasistemas.com.ar/crm/recursos/como-emitir-factura-electronica-afip/"}
}
```

---

## 5) Plan de contenido (60 días) — 16 posts (2/semana) + 3 pillar + 3 comparativas

### 5.1 Principios editoriales (para rankear en Argentina)
- Escribir en **español rioplatense** (“vos/podés” opcional; si prefieren neutral, mantener “podés” fuera).
- “Local-first”: AFIP/ARCA, MercadoPago, MercadoLibre, TiendaNube, WhatsApp.
- Cada post debe tener:
  - 1 keyword principal + 3–8 secundarias
  - H2/H3 con preguntas del usuario
  - Ejemplos y checklist
  - CTA claro (demo/WhatsApp)
  - FAQ block al final

### 5.2 Calendario 60 días (16 posts)

> Repartido por producto para construir clusters. Word count sugerido orientativo.

#### Semana 1
1) **(CRM)** Título: *Cómo emitir factura electrónica en AFIP paso a paso (Monotributo y RI) — 2026*  
   - Keyword: “cómo hacer factura electrónica AFIP”  
   - Intención: I → capturar tráfico y llevar a CTA “sistema de facturación”  
   - 2200–2800 palabras  
   - Outline:
     - Requisitos (clave fiscal, punto de venta)
     - Tipos de factura A/B/C (resumen)
     - Paso a paso en AFIP
     - Errores comunes
     - Cómo automatizar con un sistema
     - FAQ

2) **(Delivery)** Título: *Comisiones de PedidosYa y Rappi: cuánto te cuesta y cómo reducirlas (alternativas 0%)*  
   - Keyword: “comisiones PedidosYa restaurantes”  
   - Intención: I/C  
   - 1800–2400  
   - Outline:
     - Cómo funcionan comisiones
     - Ejemplos con números (margen)
     - Estrategias: canal propio + menú QR + WhatsApp
     - Calculadora simple
     - CTA: demo

#### Semana 2
3) **(CRM)** *Integración MercadoLibre + stock + facturación: guía para evitar sobreventa*  
   - Keyword: “integración MercadoLibre stock y facturación”  
   - 2000–2600

4) **(Fitness)** *Cómo fidelizar clientes como personal trainer: 9 tácticas + cómo medir adherencia*  
   - Keyword: “cómo fidelizar clientes personal trainer”  
   - 1800–2400

#### Semana 3
5) **(Delivery)** *Cómo crear un menú digital QR para tu restaurante (que puedas actualizar sin reimprimir)*  
   - Keyword: “menú digital QR para restaurantes”  
   - 1600–2200

6) **(CRM)** *Control de stock para pymes: método simple + checklist de inventario*  
   - Keyword: “cómo llevar control de stock”  
   - 2000–2600

#### Semana 4
7) **(Fitness)** *Rutinas con IA: cómo usar inteligencia artificial para crear planes (sin perder criterio profesional)*  
   - Keyword: “IA para crear rutinas de gimnasio”  
   - 2000–2600

8) **(CRM)** *Factura A, B y C: diferencias, cuándo usar cada una y ejemplos*  
   - Keyword: “factura A B C diferencia”  
   - 1600–2200

#### Semana 5
9) **(Delivery)** *Delivery propio vs apps: guía de decisión + costos (para pizzerías, empanadas y heladerías)*  
   - Keyword: “delivery propio vs apps”  
   - 2200–3000

10) **(Fitness)** *Cómo calcular macros (guía para entrenadores) + plantilla descargable*  
   - Keyword: “cómo calcular macros para ganar músculo”  
   - 2000–2600

#### Semana 6
11) **(CRM)** *POS en Argentina: qué debe tener un punto de venta para comercio minorista (AFIP + stock)*  
   - Keyword: “sistema punto de venta POS Argentina”  
   - 2000–2600

12) **(Servicios IA)** *Chatbot para WhatsApp Business: casos de uso, costos y cómo implementarlo*  
   - Keyword: “chatbot WhatsApp para negocios”  
   - 2000–2600

#### Semana 7
13) **(Delivery)** *Cómo vender por WhatsApp en un restaurante: mensajes, catálogo, horarios y automatización*  
   - Keyword: “sistema de pedidos por WhatsApp restaurante”  
   - 1800–2400

14) **(CRM)** *TiendaNube + facturación AFIP: cómo facturar automáticamente tus ventas*  
   - Keyword: “facturar ventas TiendaNube AFIP”  
   - 1800–2400

#### Semana 8
15) **(Fitness)** *Trainerize vs Hevy vs (alternativas): qué conviene para cada tipo de entrenador*  
   - Keyword: “Trainerize vs Hevy”  
   - 2200–3000

16) **(Servicios IA / Seguridad)** *Videovigilancia con IA: qué detecta, cuándo conviene y cómo se implementa en comercios*  
   - Keyword: “videovigilancia con inteligencia artificial”  
   - 2000–2600

### 5.3 Pillar pages (3) — para cada producto (evergreen, 3500–6000 palabras)

1) **Pillar CRM:** */crm/* o */crm/sistema-de-gestion-para-pymes/*  
   - Keyword: “sistema de gestión para pymes” + cluster AFIP/stock/POS/ML
   - Secciones:
     - Para quién es (pymes/monotributo/RI)
     - Módulos (facturación/stock/POS/webshop/CRM)
     - Integraciones (MercadoLibre/TiendaNube/MercadoPago)
     - Casos de uso por rubro
     - FAQs
     - CTA demo

2) **Pillar Delivery:** */delivery/* o */delivery/delivery-sin-comisiones/*  
   - Keyword: “delivery sin comisiones” + “sistema de pedidos online”
   - Secciones:
     - Costo de comisión vs canal propio
     - Menú QR + pedidos + WhatsApp + pagos
     - Fidelización y datos
     - Casos por tipo de local
     - FAQs

3) **Pillar Fitness:** */fitness/software-para-personal-trainer/*  
   - Keyword: “software para personal trainer”
   - Secciones:
     - Problemas del entrenador (tiempo, seguimiento, retención)
     - IA: rutinas + nutrición (cómo se controla)
     - Gamificación
     - Comparación con Excel
     - FAQs

### 5.4 Comparison pages (3) — alta intención (2500–4000)
1) */crm/comparativas/futuracrm-vs-xubio/*
2) */delivery/comparativas/futuradelivery-vs-pedidosya/*
3) */fitness/comparativas/futurafitness-vs-trainerize/*

Estructura recomendada:
- Para quién conviene cada uno
- Tabla features
- Precios (si no se tiene, hablar de modelos)
- Ventajas y limitaciones
- Conclusión + CTA

### 5.5 FAQs para rich snippets (por producto) — starter pack

#### FuturaCRM (10)
- ¿Sirve para monotributistas?
- ¿Emite facturas A/B/C?
- ¿Qué pasa si AFIP está caído?
- ¿Integra MercadoLibre?
- ¿Integra TiendaNube?
- ¿Puedo tener multi-sucursal?
- ¿Tiene control de stock con mínimo?
- ¿Se puede usar con lector de código de barras?
- ¿Incluye POS/caja?
- ¿Cómo es el soporte/implementación?

#### FuturaDelivery (10)
- ¿Cobra comisión por pedido?
- ¿Puedo usar mi propio delivery?
- ¿Se integra con WhatsApp?
- ¿Tiene menú QR?
- ¿Se puede cobrar con MercadoPago?
- ¿Puedo hacer combos y cupones?
- ¿Tiene zona de delivery y costo de envío?
- ¿Se puede usar para take away?
- ¿Se puede vincular con Instagram/Google?
- ¿Qué necesito para empezar?

#### FuturaFitness (10)
- ¿Para quién es: entrenador o alumno?
- ¿La IA reemplaza al entrenador?
- ¿Se pueden editar rutinas/nutrición?
- ¿Cómo se hace el seguimiento?
- ¿Tiene gamificación?
- ¿Se puede cobrar a clientes?
- ¿Tiene biblioteca de ejercicios?
- ¿Funciona en español?
- ¿Puedo exportar planes?
- ¿Qué diferencia tiene con Trainerize?

---

## 6) Plan de landings (money pages) — por producto

### 6.1 FuturaCRM — landings esenciales (SEO + conversión)
- `/crm/` (pilar)
- `/crm/precios/`
- `/crm/facturacion-electronica-afip/`
- `/crm/control-de-stock/`
- `/crm/punto-de-venta-pos/`
- `/crm/integraciones/mercadolibre/`
- `/crm/integraciones/tiendanube/`
- `/crm/integraciones/mercadopago/`
- `/crm/industrias/comercios/`
- `/crm/industrias/pymes/`

### 6.2 FuturaDelivery — landings esenciales
- `/delivery/` (pilar)
- `/delivery/precios/`
- `/delivery/menu-qr/`
- `/delivery/pedidos-por-whatsapp/`
- `/delivery/pedidos-online-restaurantes/`
- `/delivery/alternativas-pedidosya/`
- `/delivery/industrias/pizzerias/`
- `/delivery/industrias/heladerias/`

### 6.3 FuturaFitness — landings esenciales
- `/fitness/software-para-personal-trainer/` (pilar)
- `/fitness/precios/`
- `/fitness/ia-rutinas/`
- `/fitness/planes-nutricionales/`
- `/fitness/gamificacion/`
- `/fitness/seguimiento-clientes/`
- `/fitness/comparativas/`

---

## 7) Link Building (Argentina) — estrategia y targets

### 7.1 Principios
- Priorizar links **relevantes** (negocios, tecnología, pymes, gastronomía, fitness B2B) y menciones locales.
- Mezclar:
  - **Citas/directorios** (fáciles)
  - **Guest posts** (medio)
  - **Partnerships** (alto impacto)
  - **Activos linkables** (calculadoras, plantillas, estudios)

### 7.2 Directorios / listados (starter list)
Basado en investigación:
- **CESSI Directorio** (empresas de software): https://cessi.org.ar/directorio-de-empresas/
- **Guia TIC Argentina**: https://guiatic.com/ar/directorio
- **Dataprix directorio**: https://www.dataprix.com/directorio/empresas
- **PyAr empresas** (si aplica tech): https://www.python.org.ar/empresas/
- **F6S** (startups): https://www.f6s.com/companies/software/argentina/co

Otros targets típicos (validar):
- Cámaras/entidades sectoriales: gastronómicas (ej. FEHGRA), pymes, comercio local.

### 7.3 Guest posts / medios / blogs (Argentina y LatAm)
Targets sugeridos (verificar política de colaboración):
- SEO Express (marketing): https://www.seoexpress.com.ar/marketing-digital/
- Vivi Marketing: https://blog.vivi.marketing
- Buenos Aires IT: https://buenosairesit.com/blog-de-marketing-digital-y-desarrollo-web/
- Bloop Agency blog: https://bloop.agency/blog/
- BluCactus Argentina: https://www.blucactus.com.ar/blog-marketing/

Vertical Delivery/Gastro:
- Medios gastronómicos locales, asociaciones, blogs de restaurantes, proveedores POS.

Vertical Fitness:
- medios fitness B2B (MercadoFitness u otros), blogs de gestión de gimnasios.

### 7.4 Partnerships (alto valor)
- **Integraciones**: MercadoPago, TiendaNube partners, providers MercadoLibre integrators.
- **Agencias**: marketing digital local para restaurantes y gimnasios.
- **Estudios contables**: co-marketing “guía AFIP + sistema” (leads compartidos).

### 7.5 Activos linkables (para ganar enlaces naturalmente)
1. Calculadora “**Cuánto perdés por comisiones** (PedidosYa/Rappi) vs canal propio”
2. Plantilla de “**Inventario + stock mínimo**” (Google Sheets)
3. Checklist descargable “**Empezar a facturar en AFIP**”
4. Plantilla “**Check-in semanal de alumnos**” para entrenadores
5. “Estado del ecosistema” (mini estudio): encuesta a 50 pymes sobre facturación/stock

---

## 8) Métricas, tracking y stack recomendado

### 8.1 Herramientas mínimas
- Google Search Console (por dominio)
- Google Analytics 4
- Tag Manager
- Microsoft Clarity (UX)
- Screaming Frog (audits)

### 8.2 KPIs por fase
**Fase 1 (0–30 días):**
- Páginas indexadas
- Errores de cobertura
- Core Web Vitals básicos

**Fase 2 (30–60):**
- Impresiones orgánicas
- CTR por página
- posiciones 20–50 → 10–20

**Fase 3 (60–90):**
- Leads orgánicos (form/WhatsApp/demo)
- Conversion rate por landing
- Top 10 keywords no-branded

---

## 9) Roadmap de implementación (0–60 días) — tareas concretas

### Semana 1 (base técnica)
- Elegir estrategia SSG/SSR por producto
- Implementar metadatos por ruta
- Crear robots.txt + sitemap.xml
- Implementar schema Organization + Product + FAQ
- Configurar GSC

### Semana 2–3 (money pages)
- Crear landings esenciales (estructura)
- Añadir FAQ blocks
- Internal linking (pilar → clusters)

### Semana 4–8 (contenido)
- Publicar 16 posts (2/semana)
- 3 pillar + 3 comparativas
- Construir 2 activos linkables

### Link building (continuo)
- Alta en directorios
- 2 guest posts/mes
- 2 partnerships/mes

---

## 10) Apéndice — mapas de contenido por cluster (ejemplos)

### Cluster CRM “Facturación AFIP”
- Pilar: /crm/facturacion-electronica-afip/
- Soporte:
  - /crm/recursos/como-emitir-factura-electronica-afip/
  - /crm/recursos/factura-a-b-c-diferencias/
  - /crm/recursos/como-habilitar-punto-de-venta/

### Cluster Delivery “0% comisión”
- Pilar: /delivery/delivery-sin-comisiones/
- Soporte:
  - /delivery/recursos/comisiones-pedidosya-rappi/
  - /delivery/recursos/como-vender-por-whatsapp/
  - /delivery/recursos/menu-qr-paso-a-paso/

### Cluster Fitness “Software para entrenadores”
- Pilar: /fitness/software-para-personal-trainer/
- Soporte:
  - /fitness/recursos/como-fidelizar-clientes-personal-trainer/
  - /fitness/recursos/ia-para-rutinas-pros-contras/
  - /fitness/recursos/como-calcular-macros/

---

## Fuentes web consultadas (muestras relevantes)
- AFIP/Argentina.gob.ar guías facturación (paso a paso) y contenido relacionado.
- Comparativas Colppy vs Xubio (terceros): https://sistemasdefacturacionygestion.com.ar/contadores/xubio-vs-colppy/
- Información sobre alternativas “0 comisión” y menú QR (RAY, Meniu, etc.).
- Integraciones MercadoLibre (Contabilium, NeoFactura, iFactura) y TiendaNube (Xubio/Contabilium/Facturante):
  - https://contabilium.com/ar/integraciones-mercadolibre
  - https://neofactura.com.ar/integracion-mercadolibre.asp
  - https://xubio.com/ar/integraciones/tiendanube
  - https://contabilium.com/ar/integraciones-tiendanube
- Vite SSR docs (técnico): https://vite.dev/guide/ssr

---

# 11) Keyword research expandido (listas exhaustivas por intención)

A continuación se incluye un set **más amplio** de keywords por producto (además de las primarias ya listadas). El objetivo es que tengan suficiente “inventario” para:
- crear landings nuevas,
- alimentar el blog por 6–12 meses,
- y construir páginas de industria/segmento ("para pizzerías", "para ferreterías", etc.).

> Recomendación práctica: organizar en una planilla (Google Sheets) con columnas: `Keyword | Producto | Cluster | Intención | Tipo de página | Prioridad | URL target | Estado`.

---

## 11.1 FuturaCRM — lista extendida (80+ ideas adicionales)

### A) Facturación AFIP / comprobantes / CAE (I/T)
- facturación electrónica AFIP **monotributo**
- facturación electrónica AFIP **responsable inscripto**
- facturación electrónica **con CAE**
- qué es el **CAE** AFIP
- cómo obtener CAE
- cómo hacer factura C monotributo
- factura electrónica desde celular
- facturador AFIP vs sistema de facturación
- software homologado AFIP
- comprobantes en línea AFIP tutorial
- notas de crédito AFIP cómo hacer
- nota de débito AFIP cómo hacer
- remito electrónico AFIP
- punto de venta AFIP alta
- cómo dar de alta punto de venta AFIP
- factura E exportación AFIP (para futuras expansiones)
- qué factura corresponde si soy monotributista
- diferencias factura A B C ejemplos
- cuándo emitir factura A
- cuándo emitir factura B
- cuándo emitir factura C
- factura A a monotributista
- libro IVA digital qué es
- portal IVA AFIP cómo funciona
- IVA simple AFIP F.2051 (contenido evergreen de actualidad)

### B) Gestión comercial / administración (T)
- software de gestión comercial Argentina
- sistema administrativo para pymes
- software de administración de negocios
- sistema de gestión integral para pymes
- programa de administración para comercios
- sistema de ventas y stock
- software de ventas mostrador
- software de caja para comercio
- sistema de gestión para comercios con múltiples listas de precios

### C) Stock / inventario / compras (T)
- control de stock por depósito
- stock por lote y vencimiento (si aplica a rubros)
- stock por variantes (talle/color)
- inventario con código de barras
- lector de código de barras sistema
- etiquetas de productos impresión
- cómo hacer inventario en un comercio
- sistema de compras y proveedores
- órdenes de compra software
- recepción de mercadería con scanner
- stock mínimo alertas
- rotación de stock
- costos promedio ponderado stock

### D) POS / punto de venta (T)
- punto de venta para almacén
- POS para ferretería
- POS para indumentaria
- POS para librería
- POS para perfumería
- POS para minimercado
- software para kiosco
- software para supermercado chico
- caja registradora software
- arqueo de caja sistema
- cierre Z / reportes caja (si aplica)

### E) Webshop / e-commerce / omnicanal (T/C)
- tienda online integrada a stock
- e-commerce con facturación electrónica
- sincronizar stock tienda online
- sistema omnicanal ventas
- catálogo online con stock
- webshop para pymes argentina

### F) Integraciones (MercadoLibre/TiendaNube/MercadoPago) (T)
- integrar MercadoLibre con sistema de gestión
- sincronización de precios MercadoLibre
- facturación automática MercadoLibre
- notas de crédito por devoluciones MercadoLibre
- integración MercadoPago con sistema
- integración TiendaNube con facturación
- integración TiendaNube con stock
- facturación automática TiendaNube

### G) Segmentos/industrias (T)
- sistema de gestión para ferreterías
- sistema de gestión para indumentaria
- sistema de gestión para repuestos
- sistema de gestión para distribuidoras
- sistema de gestión para mayoristas
- software para emprendimientos
- software para profesionales independientes

**Páginas sugeridas:**
- `/crm/industrias/ferreterias/`, `/crm/industrias/indumentaria/`, `/crm/industrias/kioscos/` etc.

---

## 11.2 FuturaDelivery — lista extendida (80+ ideas adicionales)

### A) Dolor comisión / rentabilidad (I/C)
- cuánto cobra pedidosya a restaurantes
- cuánto cobra rappi a restaurantes
- comisión pedidosya 2026 (evergreen con update anual)
- comisión rappi 2026
- cómo bajar comisión pedidosya
- cómo negociar comisión con apps de delivery
- cómo aumentar margen en delivery
- cómo calcular precio de delivery
- cómo fijar mínimo de pedido

### B) Pedidos directos / canal propio (T)
- sistema de pedidos directos para restaurante
- plataforma de pedidos para restaurante sin intermediarios
- página web para restaurante con pedidos
- link de pedidos para instagram restaurante
- botón pedir en google mi negocio
- pedidos online desde google maps
- tienda online para comida

### C) WhatsApp (T/I)
- pedidos por WhatsApp automatizados
- catálogo WhatsApp restaurante cómo armar
- mensajes automáticos WhatsApp restaurante
- respuestas rápidas WhatsApp para delivery
- bot de WhatsApp para pedidos restaurante

### D) Menú QR (T/I)
- menú QR con fotos
- carta digital QR con precios
- menú QR multilenguaje
- menú QR para bares
- menú QR para cafeterías
- menú QR para heladerías
- cómo hacer menú QR gratis (captura) + upsell a solución completa

### E) Operación (T)
- sistema de comandas cocina
- gestión de pedidos cocina
- tiempos de preparación pedidos
- control de delivery por zonas
- costo de envío por distancia
- seguimiento de pedidos estado

### F) Fidelización (I/T)
- programa de puntos restaurante
- cupones para restaurante
- promociones delivery combos
- cómo hacer combos para delivery
- remarketing clientes restaurante (email/whatsapp)

### G) Segmentos (T)
- pedidos online para pizzería
- pedidos online para empanadas
- pedidos online para hamburguesería
- pedidos online para sushi
- pedidos online para heladería
- pedidos online para cafetería
- pedidos online para panadería

---

## 11.3 FuturaFitness — lista extendida (80+ ideas adicionales)

### A) Gestión del entrenador (T)
- software de gestión de alumnos personal trainer
- app para seguimiento de alumnos
- app para planes personalizados
- app para coaching online
- plataforma para vender planes de entrenamiento
- app para entrenadores con pagos
- app para entrenadores con recordatorios

### B) Rutinas / planificación (I/T)
- plantilla rutina gym
- cómo armar rutina full body
- rutina hipertrofia 3 días
- rutina hipertrofia 4 días
- rutina fuerza principiante
- rutina para bajar de peso gimnasio
- periodización entrenamiento fuerza

### C) Nutrición (I/T)
- plan nutricional para deportistas
- cómo calcular calorías mantenimiento
- déficit calórico cómo calcular
- superávit calórico cómo calcular
- macros para definición
- macros para volumen

### D) Retención / gamificación (I/C)
- gamificación en entrenamiento
- desafíos fitness para alumnos
- cómo mejorar adherencia entrenamiento
- cómo reducir churn clientes personal trainer

### E) Comparativas y alternativas (C)
- alternativa a trainerize
- alternativa a hevy coach
- mejor app para personal trainer

### F) Segmentos (T)
- app para entrenadores de crossfit
- app para entrenadores de powerlifting
- app para entrenadores de running
- app para estudio de pilates

---

## 11.4 Servicios IA — lista extendida (80+ ideas adicionales)

### Chatbots / WhatsApp
- chatbot WhatsApp API oficial Argentina
- automatización WhatsApp para pymes
- chatbot para inmobiliarias WhatsApp
- chatbot para turnos WhatsApp
- chatbot para soporte técnico
- bot de ventas WhatsApp

### Automatización / RPA
- automatización de procesos administrativos
- automatización de facturas y recibos
- automatización conciliación bancaria
- RPA para pymes
- n8n automatizaciones empresas

### Videovigilancia IA
- analítica de video para comercios
- detección de intrusos con IA
- reconocimiento facial para control de acceso
- conteo de personas retail

---

# 12) Análisis de SERP y “qué página construir” (por keyword tipo)

## 12.1 Matriz intención → tipo de página

- **T (software/precio/demo):** landing de producto o feature (`/crm/facturacion-electronica-afip/`, `/delivery/pedidos-online-restaurantes/`, `/fitness/software-para-personal-trainer/`).
- **C (mejores/alternativas/vs):** páginas comparativas (`/comparativas/`).
- **I (cómo hacer/guía/checklist):** blog/guías (`/recursos/`).
- **N (marca/competidor):** contenido defensivo (páginas “alternativa a X”, “vs X”) y optimizar sitelinks.

## 12.2 Patrones de contenido que Google suele premiar en AR
- Guías con pasos claros + listas.
- Contenido con ejemplos de Argentina (AFIP, MercadoPago).
- Tablas comparativas.
- FAQs directas.

## 12.3 Gaps concretos a explotar (por producto)

### CRM
- “MercadoLibre + AFIP + stock” explicado de forma “operativa”, no contable.
- Páginas por rubro con ejemplos (indumentaria: talles/colores; ferretería: SKUs, etc.).

### Delivery
- Calculadora de comisión y “modelo de costos” (comisión vs suscripción) con CTA.
- Páginas hipersegmentadas (pizzería/heladería) con copy adaptado.

### Fitness
- Contenido de IA aplicado al trabajo real del entrenador: prompts, revisión humana, cómo evitar errores.
- “Excel vs app” como comparativa evergreen.

---

# 13) Implementación técnica detallada (paso a paso) — Vite/React

> Objetivo: que un equipo dev pueda ejecutar sin ambigüedades.

## 13.1 Arquitectura recomendada: “Marketing SSG + App CSR”

Si cada producto tiene un “producto/app” (login) y un “marketing site”:
- Marketing: SSG (pre-render)
- App: CSR (bloquear indexación)

**Ejemplo de ruteo:**
- `https://futurasistemas.com.ar/crm/...` (SSG/SSR)
- `https://app.futurasistemas.com.ar/crm/...` (CSR, noindex)

## 13.2 SSG en Vite (concepto)
- Definir lista de rutas estáticas.
- Generar HTML por ruta en build.
- Servir como sitio estático en Vercel/Netlify.

## 13.3 SSR en Vite (concepto)
- `entry-client` + `entry-server`
- server Node que hace render de React

## 13.4 Reglas SEO imprescindibles

### 13.4.1 `noindex` para rutas internas
- `/app/`, `/dashboard/`, `/admin/`, `/login/` → `noindex, nofollow`.

### 13.4.2 Canonical
- 1 URL canónica por contenido.

### 13.4.3 404 y soft-404
- 404 real con status 404.

### 13.4.4 Redirects
- De `vercel.app` a dominio propio (301).

## 13.5 Sitemap: ejemplos

### Sitemap index (si hay múltiples)
- `/sitemap.xml` apunta a:
  - `/sitemap-pages.xml`
  - `/sitemap-posts.xml`

### Reglas
- `lastmod` actualizado
- incluir solo URLs indexables

## 13.6 Datos estructurados: implementación segura
- 1 bloque JSON-LD por tipo por página.
- Evitar `aggregateRating` si no hay reviews reales.

---

# 14) Plantillas de copy (landings) + estructura on-page

## 14.1 Landing template (H1/H2 + secciones)

**H1:** beneficio + ICP + diferenciador local

**Secciones recomendadas:**
1. Problema (dolor)
2. Solución (cómo lo resuelve)
3. Diferenciales (3–6)
4. Integraciones
5. Cómo empezar (3 pasos)
6. Testimonios (si hay)
7. FAQ
8. CTA (sticky)

## 14.2 Ejemplo de copy — FuturaDelivery “0% comisión”
- H1: “Pedidos directos para restaurantes — 0% comisión por pedido”
- Sub: “Menú QR + WhatsApp + pagos. Pagás una suscripción mensual y te quedás con tus clientes.”

## 14.3 Ejemplo de copy — FuturaCRM “AFIP + stock + MercadoLibre”
- H1: “Facturación AFIP + stock + POS + MercadoLibre en un solo sistema”
- Sub: “Para pymes y comercios en Argentina. Menos tareas manuales, menos errores, más control.”

---

# 15) Outreach y link building — playbook

## 15.1 Email template (guest post)
Asunto: Propuesta de artículo para [SITIO] sobre [TEMA]

Hola [Nombre],

Soy [Nombre] de Futura Sistemas. Estamos publicando guías prácticas para pymes en Argentina (AFIP, stock, e-commerce). 

Me gustaría proponer un artículo para [Sitio] sobre: **[Título propuesto]**.

Incluye:
- checklist descargable,
- ejemplos reales en Argentina,
- y un resumen accionable.

¿Te interesa que lo enviemos?

Gracias,
[Nombre]
[Cargo]
[Web]

## 15.2 Plantilla partnership (integraciones)
- propuesta: “guía conjunta + webinar + landing co-branded + backlink”

---

# 16) Plan editorial detallado (16 posts) — brief completo por pieza

A continuación se detalla cada post con:
- keyword principal + secundarias,
- intención,
- objetivo de conversión,
- estructura H2/H3 sugerida,
- snippet target,
- FAQs para esquema.

> Convención: cada post debe enlazar internamente a (1) pillar page del producto y (2) 2–4 páginas/recursos relacionados.

---

## Post 1 — CRM
**URL sugerida:** `/crm/recursos/como-emitir-factura-electronica-afip/`  
**Keyword principal:** cómo emitir factura electrónica AFIP  
**Secundarias:** comprobantes en línea, punto de venta AFIP, CAE, factura C monotributo, factura A/B (mención)  
**Intención:** Informacional (I) con puente a transaccional  
**Objetivo:** capturar búsquedas “cómo” y convertir a demo (software) + descarga checklist

**Outline recomendado (H2/H3):**
- H2: Qué necesitás antes de emitir una factura electrónica
  - H3: CUIT + Clave Fiscal: niveles y servicios
  - H3: Alta de punto de venta (electrónico)
- H2: Tipos de factura (A/B/C) — resumen rápido
- H2: Paso a paso en AFIP (Comprobantes en línea)
  - H3: Selección punto de venta
  - H3: Datos del receptor
  - H3: Carga de ítems / concepto
  - H3: Confirmación / CAE
  - H3: Descargar PDF / envío por email
- H2: Errores comunes y cómo evitarlos
- H2: ¿Cuándo conviene usar un sistema en lugar del portal de AFIP?
- H2: Checklist descargable
- H2: Conclusión + CTA

**Snippet target:** “Lista de pasos” (featured snippet tipo checklist).  
**FAQs (para schema):**
- ¿Qué necesito para emitir factura electrónica por primera vez?
- ¿Cómo doy de alta un punto de venta?
- ¿Qué hago si AFIP está caído?
- ¿Qué diferencia hay entre factura A/B/C?

---

## Post 2 — Delivery
**URL sugerida:** `/delivery/recursos/comisiones-pedidosya-rappi/`  
**Keyword principal:** comisiones PedidosYa restaurantes  
**Secundarias:** comisión Rappi, cómo reducir comisiones delivery, delivery propio vs apps  
**Intención:** I/C  
**Objetivo:** instalar el framing “comisión vs suscripción” + empujar a demo

**Outline:**
- H2: Cómo funcionan las comisiones (marketplace + logística)
- H2: Ejemplos con números (margen)
  - H3: Caso ticket promedio ARS X
  - H3: Caso ticket promedio ARS Y
- H2: 5 formas de reducir comisiones
  - H3: Canal propio (web/app)
  - H3: WhatsApp + menú QR
  - H3: Promos para migrar clientes
  - H3: Delivery propio
  - H3: Negociación
- H2: Alternativa: suscripción mensual 0% comisión — cuándo conviene
- H2: Checklist para migrar a pedidos directos
- H2: CTA

**Snippet target:** “Tabla comparativa” + “lista de estrategias”.

---

## Post 3 — CRM
**URL:** `/crm/recursos/integracion-mercadolibre-stock-facturacion/`  
**Keyword:** integración MercadoLibre stock y facturación  
**Intención:** I/T  
**Objetivo:** captar vendedores y comercios omnicanal

**Outline:**
- H2: Problema típico: sobreventa y conciliación manual
- H2: Qué datos conviene sincronizar (stock, precio, estado, envío)
- H2: Flujo recomendado (orden → factura → envío → postventa)
- H2: Notas de crédito por devoluciones
- H2: Checklist de implementación
- H2: CTA

---

## Post 4 — Fitness
**URL:** `/fitness/recursos/como-fidelizar-clientes-personal-trainer/`  
**Keyword:** cómo fidelizar clientes personal trainer  
**Secundarias:** retención gimnasio, gamificación fitness, adherencia entrenamiento  
**Intención:** I  
**Objetivo:** convertir entrenadores a prueba/demo

**Outline:**
- H2: Por qué se van los clientes (causas reales)
- H2: 9 tácticas de retención
  - H3: Onboarding 7 días
  - H3: Check-ins semanales
  - H3: Gamificación (puntos/desafíos)
  - H3: Seguimiento de progreso
  - H3: Comunicación WhatsApp/recordatorios
  - H3: Micro-objetivos
  - H3: Comunidad
  - H3: Planes escalonados
  - H3: Reporte mensual
- H2: Métricas (churn, adherencia, sesiones)
- H2: Herramientas (cómo una app ayuda)
- H2: CTA

---

## Post 5 — Delivery
**URL:** `/delivery/recursos/como-hacer-menu-qr-restaurante/`  
**Keyword:** menú digital QR para restaurantes  
**Intención:** I/T

**Outline:**
- H2: Qué es un menú QR (y qué NO es)
- H2: Elementos mínimos (categorías, fotos, alérgenos, precios)
- H2: Cómo actualizar sin reimprimir
- H2: Cómo convertir menú QR en pedidos
- H2: CTA

---

## Post 6 — CRM
**URL:** `/crm/recursos/como-llevar-control-de-stock/`  
**Keyword:** cómo llevar control de stock  
**Intención:** I

**Outline:**
- H2: Stock mínimo y rotación
- H2: Inventario inicial (paso a paso)
- H2: Entradas y salidas
- H2: Errores típicos
- H2: Plantilla descargable
- H2: CTA

---

## Post 7 — Fitness
**URL:** `/fitness/recursos/ia-para-crear-rutinas/`  
**Keyword:** IA para crear rutinas de gimnasio  
**Intención:** I/C

**Outline:**
- H2: Qué puede y qué no puede hacer la IA
- H2: Flujo recomendado “IA + criterio profesional”
- H2: Prompts (ejemplos)
- H2: Checklist de seguridad
- H2: CTA

---

## Post 8 — CRM
**URL:** `/crm/recursos/factura-a-b-c-diferencias/`  
**Keyword:** factura A B C diferencia  
**Intención:** I

**Outline:**
- H2: Factura A
- H2: Factura B
- H2: Factura C
- H2: Tabla resumen
- H2: Errores frecuentes
- H2: CTA

---

## Post 9 — Delivery
**URL:** `/delivery/recursos/delivery-propio-vs-apps/`  
**Keyword:** delivery propio vs apps  
**Intención:** C

**Outline:**
- H2: Pros/contras
- H2: Modelo de costos
- H2: Estrategia híbrida
- H2: CTA

---

## Post 10 — Fitness
**URL:** `/fitness/recursos/como-calcular-macros/`  
**Keyword:** cómo calcular macros  
**Intención:** I

**Outline:**
- H2: Calorías mantenimiento
- H2: Déficit vs superávit
- H2: Proteínas/carbohidratos/grasas
- H2: Ejemplos
- H2: Plantilla
- H2: CTA

---

## Post 11 — CRM
**URL:** `/crm/recursos/pos-argentina-que-necesita/`  
**Keyword:** sistema punto de venta POS Argentina  
**Intención:** I/T

**Outline:**
- H2: Funciones mínimas
- H2: Integración AFIP
- H2: Stock
- H2: Multi-sucursal
- H2: CTA

---

## Post 12 — Servicios IA
**URL:** `/servicios/recursos/chatbot-whatsapp-business/`  
**Keyword:** chatbot WhatsApp para negocios  
**Intención:** I/T

**Outline:**
- H2: Casos de uso
- H2: Costos/beneficios
- H2: Implementación (pasos)
- H2: CTA

---

## Post 13 — Delivery
**URL:** `/delivery/recursos/como-vender-por-whatsapp-restaurante/`  
**Keyword:** sistema de pedidos por WhatsApp restaurante  
**Intención:** I/T

**Outline:**
- H2: Estructura de mensajes
- H2: Catálogo
- H2: Confirmación y pago
- H2: Automatización
- H2: CTA

---

## Post 14 — CRM
**URL:** `/crm/recursos/tiendanube-facturacion-afip/`  
**Keyword:** facturar ventas TiendaNube AFIP  
**Intención:** I/T

**Outline:**
- H2: Opciones: facturar manual vs automático
- H2: Qué integrar
- H2: Errores
- H2: CTA

---

## Post 15 — Fitness (comparativa)
**URL:** `/fitness/recursos/trainerize-vs-hevy/`  
**Keyword:** Trainerize vs Hevy  
**Intención:** C

**Outline:**
- H2: Para quién es cada uno
- H2: Tabla
- H2: Recomendación por tipo de entrenador
- H2: CTA

---

## Post 16 — Servicios IA (seguridad)
**URL:** `/servicios/recursos/videovigilancia-con-ia/`  
**Keyword:** videovigilancia con inteligencia artificial  
**Intención:** I/T

**Outline:**
- H2: Qué detecta
- H2: Casos por industria
- H2: Implementación
- H2: CTA

---

# 17) On-page SEO: checklist exhaustivo por página

## 17.1 Checklist general (aplicar a every landing/post)
- Title único con keyword (sin truncar)
- Meta description orientada a click
- H1 único
- H2/H3 con preguntas reales (People Also Ask)
- 1 imagen optimizada con alt keyword
- Internal links (mínimo 3)
- CTA visible (sticky si es landing)
- FAQ block + schema FAQPage
- Breadcrumbs (schema BreadcrumbList)
- Open Graph (imagen 1200x630)
- Canonical
- Datos de contacto (NAP si aplica)

## 17.2 Template de Title/Description por tipo

### Landing transaccional (T)
- Title: `Software [categoría] en Argentina | [Marca]`  
- Description: `[Beneficio 1]. [Beneficio 2]. Integración [local]. Pedí demo.`

### Comparativa (C)
- Title: `[Producto] vs [Competidor] — diferencias, precios y qué conviene`  
- Description: `Comparación completa: funciones, pros/contras y para quién conviene cada opción en Argentina.`

### Guía (I)
- Title: `Cómo [hacer X] en Argentina (paso a paso) — 2026`  
- Description: `Guía clara + checklist + errores comunes y cómo automatizarlo.`

## 17.3 Interlinking: reglas
- Pilar enlaza a 6–12 cluster posts.
- Cada cluster post enlaza de vuelta al pilar y a 2–3 posts del cluster.
- Comparativas enlazan a pilar y a pricing.

---

# 18) Keyword bank mega (modificadores + preguntas) — para expandir a 12 meses

## 18.1 Modificadores transaccionales (añadir a keywords base)
- precio, costos, plan, demo, prueba gratis, contratar, implementación, sistema, software, plataforma, app
- para pymes, para monotributistas, para responsables inscriptos, para comercio, para restaurante, para entrenador
- en Argentina, en Buenos Aires, en Córdoba, en Rosario (geo pages si hay estrategia local)

## 18.2 Modificadores de comparación
- vs, alternativas, mejor, top, comparación, opiniones, reseñas

## 18.3 Preguntas frecuentes que Google muestra (plantillas)
- qué es…, cómo funciona…, cómo hacer…, cuánto cuesta…, qué necesito…, cuál conviene…, cuál es mejor…, cómo integrar…, cómo automatizar…, cómo reducir…

## 18.4 Banco de preguntas por producto (50+ c/u)

### CRM — preguntas (50)
1. ¿Qué software necesito para facturar en AFIP?
2. ¿Cuál es el mejor sistema de facturación para monotributo?
3. ¿Cómo hago facturas A/B/C?
4. ¿Cómo doy de alta un punto de venta?
5. ¿Qué es el CAE y para qué sirve?
6. ¿Puedo facturar sin entrar a AFIP?
7. ¿Cómo emitir nota de crédito?
8. ¿Cómo llevar stock en un negocio pequeño?
9. ¿Cómo hacer inventario rápido?
10. ¿Qué POS conviene para comercio minorista?
11. ¿Cómo integrar MercadoLibre a mi sistema?
12. ¿Cómo evitar sobreventa en MercadoLibre?
13. ¿Cómo facturar ventas de TiendaNube?
14. ¿Cómo conciliar ventas y cobros?
15. ¿Qué es el Libro IVA Digital?
16. ¿Qué es IVA Simple?
17. ¿Cómo exportar reportes?
18. ¿Cómo hacer arqueo de caja?
19. ¿Cómo manejar cuentas corrientes?
20. ¿Se puede multi-sucursal?
21. ¿Cómo manejar listas de precios?
22. ¿Cómo administrar proveedores?
23. ¿Cómo generar remitos?
24. ¿Qué integra con MercadoPago?
25. ¿Cómo hacer presupuestos?
26. ¿Cómo pasar de Excel a un sistema?
27. ¿Qué pasa si se corta internet?
28. ¿Cómo manejar devoluciones?
29. ¿Cómo registrar compras?
30. ¿Cómo ver rentabilidad por producto?
31. ¿Cómo registrar gastos?
32. ¿Cómo controlar stock mínimo?
33. ¿Cómo configurar productos con variantes?
34. ¿Cómo emitir facturas desde el celular?
35. ¿Cómo automatizar facturación?
36. ¿Cómo elegir ERP para pymes?
37. ¿Qué diferencia hay entre ERP y sistema de gestión?
38. ¿Un sistema puede hacer contabilidad automática?
39. ¿Cómo integrarlo con mi contador?
40. ¿Qué datos se deben respaldar?
41. ¿Qué tan seguro es en la nube?
42. ¿Cómo migrar datos?
43. ¿Cuánto tarda una implementación?
44. ¿Qué soporte necesito?
45. ¿Cómo capacitar a mi equipo?
46. ¿Cómo limitar permisos por usuario?
47. ¿Cómo manejar promociones?
48. ¿Cómo imprimir etiquetas?
49. ¿Cómo trabajar con lector de código de barras?
50. ¿Cómo medir ventas por vendedor?

### Delivery — preguntas (50)
1. ¿Cuánto cobra PedidosYa a los restaurantes?
2. ¿Cuánto cobra Rappi?
3. ¿Cómo bajar comisiones de delivery?
4. ¿Conviene tener delivery propio?
5. ¿Cómo crear pedidos directos?
6. ¿Cómo vender por WhatsApp?
7. ¿Qué es un menú QR?
8. ¿Cómo crear menú QR gratis?
9. ¿Cómo cobrar con MercadoPago?
10. ¿Cómo aumentar pedidos sin apps?
11. ¿Cómo captar pedidos desde Google?
12. ¿Cómo poner link de pedidos en Instagram?
13. ¿Cómo calcular costo de envío?
14. ¿Cómo definir zona de delivery?
15. ¿Cómo aumentar ticket promedio?
16. ¿Cómo armar combos para delivery?
17. ¿Cómo hacer cupones?
18. ¿Cómo fidelizar clientes?
19. ¿Cómo evitar errores en cocina?
20. ¿Cómo imprimir comandas?
21. ¿Cómo gestionar horarios?
22. ¿Cómo manejar productos agotados?
23. ¿Cómo actualizar precios rápido?
24. ¿Qué métricas mirar?
25. ¿Cómo reducir cancelaciones?
26. ¿Cómo optimizar tiempos de entrega?
27. ¿Cómo escalar sin perder control?
28. ¿Cómo manejar múltiples sucursales?
29. ¿Cómo operar con dark kitchen?
30. ¿Cómo diseñar menú para delivery?
31. ¿Qué platos viajan mejor?
32. ¿Cómo sacar mejores fotos?
33. ¿Cómo hacer promociones por día?
34. ¿Cómo migrar clientes de apps a canal propio?
35. ¿Cómo armar base de datos de clientes?
36. ¿Cómo enviar campañas por WhatsApp?
37. ¿Cómo automatizar confirmaciones?
38. ¿Cómo gestionar pagos y contraentrega?
39. ¿Cómo gestionar devoluciones y reclamos?
40. ¿Cómo manejar repartidores?
41. ¿Conviene tercerizar logística?
42. ¿Cómo medir rentabilidad por canal?
43. ¿Cómo medir CAC orgánico?
44. ¿Cómo implementar un sistema rápido?
45. ¿Qué necesito para empezar?
46. ¿Cuánto cuesta una plataforma 0% comisión?
47. ¿Sirve para take away?
48. ¿Se integra con POS?
49. ¿Cómo conectar con impresora?
50. ¿Cómo usar QR en mesas?

### Fitness — preguntas (50)
1. ¿Cuál es el mejor software para personal trainer?
2. ¿Qué app conviene para entrenadores?
3. ¿Cómo crear rutinas rápido?
4. ¿Cómo armar plan nutricional?
5. ¿Cómo calcular macros?
6. ¿Cómo mejorar adherencia de alumnos?
7. ¿Cómo fidelizar clientes?
8. ¿Cómo vender planes online?
9. ¿Cómo cobrar a clientes?
10. ¿Cómo hacer seguimiento del progreso?
11. ¿Cómo registrar medidas?
12. ¿Cómo evaluar al cliente al inicio?
13. ¿Qué es periodización?
14. ¿Cómo armar rutina hipertrofia?
15. ¿Cómo armar rutina fuerza?
16. ¿Cómo ajustar cargas?
17. ¿Qué es RPE?
18. ¿Cómo usar gamificación?
19. ¿Qué desafíos proponer?
20. ¿Cómo hacer check-in semanal?
21. ¿Cómo crear comunidad?
22. ¿Cómo reducir churn?
23. ¿Cómo estructurar onboarding?
24. ¿Cómo usar IA sin errores?
25. ¿Cómo revisar un plan generado por IA?
26. ¿Cómo personalizar por lesión?
27. ¿Cómo adaptar a equipamiento?
28. ¿Cómo manejar dietas y preferencias?
29. ¿Cómo crear biblioteca de ejercicios?
30. ¿Cómo enviar rutinas por app?
31. ¿Cómo medir cumplimiento?
32. ¿Cómo reportar resultados a cliente?
33. ¿Cómo escalar a muchos alumnos?
34. ¿Cómo organizar sesiones?
35. ¿Cómo planificar microciclos?
36. ¿Cómo integrar con WhatsApp?
37. ¿Cómo automatizar recordatorios?
38. ¿Cómo segmentar clientes?
39. ¿Cómo definir precios?
40. ¿Cómo crear planes premium?
41. ¿Cómo diferenciarse de Trainerize?
42. ¿Cómo diferenciarse de Hevy?
43. ¿Cómo captar leads?
44. ¿Cómo hacer marketing de personal trainer?
45. ¿Cómo ofrecer seguimiento remoto?
46. ¿Cómo administrar parq y consentimientos?
47. ¿Cómo exportar planes?
48. ¿Cómo usar plantillas?
49. ¿Cómo aumentar renovaciones?
50. ¿Qué métricas mirar?

---

# 19) Competidores: mapa de contenidos y “qué replicar mejor” (por vertical)

## 19.1 CRM / AFIP / gestión

### Principales competidores directos (Argentina)
- **Colppy** (contabilidad + gestión en la nube)
- **Xubio** (contabilidad + facturación + integraciones; fuerte en contadores)
- **Calipso** (ERP más enterprise)

### Competidores/alternativas del ecosistema (capturan SERP)
- **Alegra**, **TusFacturasAPP**, **Contabilium**, **Tributo Simple** (facturación/integraciones)
- **TiendaNube** (blog educativo + marketplace de apps)
- **Contagram** (contenidos informativos sobre facturación)
- Directorios: **comparasoftware**, **Capterra**, **GetApp**

### Qué páginas suelen rankear (patrones)
1) **Landings “producto”**: /facturacion/, /contabilidad/, /precios/  
2) **Integraciones**: /integraciones/tiendanube, /integraciones/mercadolibre  
3) **Guías**:
   - “Cómo emitir factura electrónica”
   - “Factura A/B/C: diferencias”
   - “Cómo habilitar punto de venta”

**Conclusión táctica:**
- Para ganar rápido: crear 6–10 guías evergreen que atacan preguntas AFIP.
- Para convertir: landings por feature (AFIP, stock, POS, MercadoLibre, TiendaNube).

### Gaps observables
- Muchos competidores hablan para “contador”; hay espacio para hablar para:
  - el dueño de comercio,
  - el encargado de stock,
  - el vendedor de MercadoLibre.

**Contenido gap concreto (ideas):**
- “Checklist de cierre de mes” para pymes (ventas + stock + IVA)
- “Cómo calcular rentabilidad por producto (incluye costos, comisiones, envíos)”
- “Errores típicos en MercadoLibre cuando no sincronizás stock”

---

## 19.2 Delivery / restaurantes

### Competidores y sustitutos
- Marketplaces: **PedidosYa**, **Rappi** (dominancia por marca)
- Alternativas “0 comisión” / canal propio: **RAY**, **Pedidosfree**, **RestoSimple**, **Meniu** y muchos “menú QR”.

### Qué páginas rankean
- Notas/guías sobre comisiones y cómo reducirlas.
- Landings de menú QR gratis.
- Páginas de “planes” y “precios” de plataformas.

### Gaps
- Pocas páginas con enfoque “unit economics” y calculadora.
- Falta de narrativa “datos del cliente”: el valor no es solo ahorrarte comisión, es **construir base propia**.

---

## 19.3 Fitness (software para entrenadores)

### Competidores
- Internacionales: **Trainerize**, **TrueCoach**, **Hevy Coach**, **Harbiz**, **Fitbod** (más B2C)
- Gestión gimnasios: **Trainingym**
- Directorios: Capterra/GetApp/Comparasoftware

### Qué contenido domina
- Comparativas (X vs Y)
- Landings de features
- Artículos de retención/gamificación

### Gaps
- Localización Argentina (formas de cobro, hábitos de WhatsApp, pricing ARS, cultura).
- “IA aplicada al proceso del entrenador” con ejemplos y control de calidad.

---

# 20) Link building — lista ampliada de targets (AR/LatAm) + táctica por tipo

> Importante: antes de outreach, preparar “activos” que valgan el link (calculadora, plantilla, guía definitiva, estudio de datos).

## 20.1 Directorios/marketplaces (citas)
- CESSI — Directorio empresas (perfil completo + enlace)
- GuiaTIC — perfil proveedor
- Dataprix — perfil
- Python Argentina (si aplica)
- F6S — perfil startup
- Directorios SaaS/IT regionales (validar manualmente): SaasArgentina, comparasoftware, GetApp (perfil), Capterra (perfil)

## 20.2 Cámaras, asociaciones y comunidades
- Asociaciones gastronómicas (ej. FEHGRA — buscar capítulos locales)
- Centros comerciales / cámaras de comercio municipales
- Comunidades de emprendedores (Meetup, coworks, incubadoras)

## 20.3 Partners de integración (links de alto valor)
- Integradores MercadoLibre (ej. plataformas que listan integraciones)
- TiendaNube marketplace (si integran)
- Proveedores de pago (MercadoPago) — casos y partners

## 20.4 Medios y blogs (guest posts)
- Blogs de marketing digital (SEO Express, Vivi Marketing, etc.)
- Medios de negocios (local/regional)
- Blogs de e-commerce (guías TiendaNube, agencias e-commerce)

## 20.5 Estrategia por producto

### CRM
- Outreach a estudios contables: “Guía AFIP + planilla + demo”
- Outreach a agencias e-commerce: “MercadoLibre + TiendaNube + stock”

### Delivery
- Outreach a proveedores gastronómicos (insumos, packaging, POS): contenido conjunto
- Outreach a medios gastronómicos locales: “cómo reducir comisión”

### Fitness
- Outreach a escuelas/cursos de entrenadores: recursos gratuitos + descuento
- Outreach a comunidades fitness: guías de negocio del entrenador (B2B)

---

# 21) Implementación técnica — recetas (código/estructura) para ejecutar

> Sección orientada a devs. Adaptar según stack real (Vite + React Router).

## 21.1 Meta tags por ruta (React)
Recomendado: `react-helmet-async`.

Ejemplo:
```jsx
import { Helmet } from 'react-helmet-async'

export function Seo({ title, description, canonical }) {
  return (
    <Helmet>
      <title>{title}</title>
      <meta name="description" content={description} />
      {canonical && <link rel="canonical" href={canonical} />}
    </Helmet>
  )
}
```

## 21.2 Robots + sitemap en build
- Generar `public/robots.txt`
- Generar `public/sitemap.xml` con script (Node) leyendo rutas.

Ejemplo (pseudo):
```js
// scripts/generate-sitemap.js
const fs = require('fs')
const routes = [
  '/', '/crm/', '/crm/precios/', '/crm/recursos/...'
]
const base = 'https://futurasistemas.com.ar'

const xml = `<?xml version="1.0" encoding="UTF-8"?>\n` +
`<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n` +
routes.map(r => `  <url><loc>${base}${r}</loc></url>`).join('\n') +
`\n</urlset>`

fs.writeFileSync('public/sitemap.xml', xml)
```

## 21.3 Pre-render (SSG) — checklist
- Listar rutas
- Asegurar que cada ruta se renderiza sin calls bloqueantes
- Publicar HTML estático

## 21.4 SSR — checklist
- Asegurar status codes (200/404)
- Evitar “hydration mismatch”
- Renderizar contenido principal en server

## 21.5 Validación
- `site:dominio` en Google
- Rich Results Test
- Lighthouse (CWV)

---

# 22) Mega-listas de keywords (para 6–12 meses) — por producto

Estas listas están pensadas para poblar:
- páginas de funcionalidad,
- páginas por industria,
- y backlog de contenidos.

> Sugerencia: elegir las 50 de mayor intención por producto para Q1 y el resto para Q2/Q3.

---

## 22.1 FuturaCRM — mega lista adicional (150)

### Funcionalidad/feature (T/C)
- software de facturación AFIP con stock
- software de facturación con punto de venta
- sistema de gestión con facturación electrónica
- sistema administrativo con stock y caja
- programa para emitir comprobantes AFIP
- software para CAE automático
- software para nota de crédito AFIP
- sistema para remitos y facturas
- sistema para presupuestos y remitos
- software para cuentas corrientes
- sistema para cuentas corrientes clientes
- sistema para cuentas corrientes proveedores
- software para gestión de compras
- software para órdenes de compra
- software para gestión de gastos
- software para registrar gastos
- reporte de rentabilidad por producto sistema
- reporte de ventas por vendedor
- software de caja con arqueo
- cierre de caja sistema
- software multiusuario para comercio
- permisos por usuario sistema de gestión
- software para control de stock mínimo
- sistema para inventario con lector
- sistema con código de barras
- software para imprimir etiquetas
- sistema de precios por lista
- software con descuentos por cliente
- sistema de gestión multiempresa
- sistema de gestión multi sucursal
- stock centralizado multi sucursal
- transferencias entre depósitos sistema
- sistema de gestión en la nube Argentina
- software de gestión online Argentina
- sistema de gestión con soporte en Argentina

### Integraciones (T)
- sistema que integra MercadoLibre
- sistema que integra MercadoPago
- sistema que integra TiendaNube
- sistema que integra WooCommerce
- sistema que integra Shopify Argentina (si apuntan a mercado)
- integración AFIP API
- integración con facturación electrónica
- sincronizar stock MercadoLibre
- actualizar precios MercadoLibre automático
- facturación masiva MercadoLibre
- facturación automática por ventas MercadoLibre
- facturación automática TiendaNube

### Por rubro (T)
- sistema de gestión para kioscos con facturación
- sistema de gestión para almacén
- sistema de gestión para minimercado
- sistema de gestión para ferretería
- sistema de gestión para casa de repuestos
- sistema de gestión para autopartes
- sistema de gestión para librería
- sistema de gestión para bazar
- sistema de gestión para perfumería
- sistema de gestión para farmacia (si aplica regulatorio)
- sistema de gestión para dietética
- sistema de gestión para vinoteca
- sistema de gestión para mayoristas
- sistema de gestión para distribuidoras
- sistema de gestión para corralón
- sistema de gestión para regalería
- sistema de gestión para indumentaria talles colores
- sistema de gestión para calzado talles
- sistema de gestión para electrónica

### Queries “mejor / alternativas / opiniones” (C)
- mejor software facturación AFIP
- mejores sistemas de gestión para pymes Argentina
- mejor sistema de stock para comercio
- mejor punto de venta Argentina
- alternativa a Colppy
- alternativa a Xubio
- alternativa a Calipso
- Colppy opiniones
- Xubio opiniones
- Calipso ERP opiniones

### Preguntas “cómo” (I)
- cómo elegir sistema de gestión
- cómo migrar de Excel a un sistema
- cómo hacer control de stock con código de barras
- cómo facturar ventas online
- cómo integrar MercadoLibre con stock
- cómo emitir nota de crédito

*(continuar completando en planilla con combinaciones de: [feature] + [rubro] + [Argentina])*

---

## 22.2 FuturaDelivery — mega lista adicional (150)

### Canal propio / pedidos directos (T)
- plataforma pedidos directos restaurante
- sistema pedidos web restaurante
- página de pedidos para restaurante
- link de pedidos restaurante
- sistema de pedidos con carrito
- pedidos online sin comisión
- pedidos online sin marketplace
- sistema para recibir pedidos en cocina
- sistema de comandas para delivery

### Menú QR (T/I)
- menú QR con pedidos
- menú QR con pagos
- carta digital QR restaurante
- menú digital QR para bar
- menú digital QR para cafetería
- menú QR para food truck
- menú QR para hotel

### WhatsApp (T)
- pedidos por WhatsApp restaurante sistema
- bot WhatsApp pedidos restaurante
- automatizar WhatsApp restaurante
- mensajes automáticos delivery
- catálogo WhatsApp para delivery

### Rentabilidad / costos (I/C)
- cómo reducir comisión pedidosya
- cómo reducir comisión rappi
- cuánto cuesta pedidosya para restaurantes
- cuánto cuesta rappi para restaurantes
- cuánto cuesta tener delivery propio
- cómo calcular costo de envío
- cómo fijar mínimo de compra

### Rubros (T)
- pedidos online pizzería
- pedidos online empanadas
- pedidos online hamburguesería
- pedidos online sushi
- pedidos online heladería
- pedidos online cafetería
- pedidos online panadería

### Comparativas (C)
- alternativa a pedidosya para restaurantes
- alternativa a rappi para restaurantes
- pedidosya vs delivery propio
- rappi vs delivery propio
- menú qr gratis vs pago

---

## 22.3 FuturaFitness — mega lista adicional (150)

### Software para entrenadores (T)
- software para entrenadores personales
- app para personal trainer en español
- plataforma para entrenadores online
- app para gestionar alumnos
- app para seguimiento de progreso
- app para rutinas y dieta

### IA (I/C)
- inteligencia artificial para entrenadores
- IA para planes nutricionales
- IA para rutinas personalizadas
- generador de rutinas con IA
- generador de dieta con IA

### Retención/gamificación (I)
- gamificación para entrenadores
- desafíos fitness para alumnos
- retención clientes personal trainer
- adherencia a entrenamiento cómo mejorar

### Comparativas (C)
- alternativa a trainerize
- trainerize vs hevy
- hevy coach vs truecoach

### Nichos (T)
- app para entrenadores de crossfit
- app para entrenadores de powerlifting
- app para pilates

---

## 22.4 Servicios IA — mega lista adicional (150)

- chatbot para empresas Argentina
- chatbot WhatsApp para ventas
- chatbot WhatsApp para soporte
- asistente virtual IA 24/7
- automatización de procesos administrativos
- RPA para pymes
- automatización con n8n
- videovigilancia con IA
- analítica de video para comercios

---

# 23) Blueprints de landings (SEO + conversión) — lista lista para escribir

> Formato: **URL / keyword / title / H1 / secciones / FAQs**.

---

## 23.1 FuturaCRM — blueprints (10)

### (1) /crm/
- **Keyword:** sistema de gestión para pymes
- **Title:** Sistema de gestión para pymes en Argentina | FuturaCRM
- **H1:** Gestión completa para pymes: AFIP + stock + POS + MercadoLibre
- **Secciones:**
  1. Problema: falta de control / tareas repetitivas
  2. Solución: módulos (facturación, stock, POS, webshop, CRM)
  3. Integraciones (MercadoLibre, TiendaNube, MercadoPago)
  4. Casos por rubro (cards)
  5. Cómo se implementa (3 pasos)
  6. Preguntas frecuentes
  7. CTA demo + WhatsApp
- **FAQs:** ¿Monotributo? ¿RI? ¿Multi-sucursal? ¿Soporte?

### (2) /crm/precios/
- **Keyword:** precio software facturación AFIP
- **Title:** Precios | FuturaCRM (Facturación AFIP + stock + POS)
- **H1:** Planes de FuturaCRM
- **Secciones:** tabla planes, qué incluye, add-ons (integraciones), onboarding.
- **FAQs:** ¿Hay prueba? ¿Qué pasa con usuarios? ¿Migración?

### (3) /crm/facturacion-electronica-afip/
- **Keyword:** software facturación electrónica AFIP
- **Title:** Software de facturación electrónica AFIP | FuturaCRM
- **H1:** Facturá en AFIP sin complicarte
- **Secciones:**
  - Qué podés emitir (A/B/C/NC/ND)
  - Flujo CAE
  - Casos (monotributo/RI)
  - CTA
- **FAQs:** punto de venta, CAE, caídas AFIP.

### (4) /crm/control-de-stock/
- **Keyword:** software de stock e inventario
- **Title:** Control de stock e inventario en la nube | FuturaCRM
- **H1:** Stock en tiempo real (sin planillas)
- **Secciones:** mínimo, variantes, depósitos, scanner.

### (5) /crm/punto-de-venta-pos/
- **Keyword:** sistema POS Argentina
- **Title:** Punto de venta (POS) para comercios en Argentina | FuturaCRM
- **H1:** Vendé rápido en mostrador con stock integrado
- **Secciones:** caja, arqueo, precios, reportes.

### (6) /crm/integraciones/mercadolibre/
- **Keyword:** integración MercadoLibre stock facturación
- **Title:** Integración MercadoLibre + stock + facturación | FuturaCRM
- **H1:** Evitá sobreventa y automatizá tu operación
- **Secciones:** qué sincroniza, flujo, devoluciones.

### (7) /crm/integraciones/tiendanube/
- **Keyword:** facturación TiendaNube AFIP
- **Title:** TiendaNube + Facturación AFIP | FuturaCRM
- **H1:** Facturá ventas de TiendaNube automáticamente

### (8) /crm/industrias/indumentaria/
- **Keyword:** sistema de gestión para indumentaria
- **Title:** Sistema de gestión para indumentaria (talles/colores) | FuturaCRM
- **H1:** Control de stock por variantes + POS + AFIP

### (9) /crm/industrias/ferreterias/
- **Keyword:** sistema de gestión para ferretería
- **Title:** Sistema de gestión para ferreterías | FuturaCRM
- **H1:** Miles de SKUs, stock y ventas sin perder control

### (10) /crm/comparativas/futuracrm-vs-xubio/
- **Keyword:** FuturaCRM vs Xubio
- **Title:** FuturaCRM vs Xubio: diferencias y qué conviene
- **H1:** Comparación: para pymes operativas vs foco contable

---

## 23.2 FuturaDelivery — blueprints (8)

### (1) /delivery/
- **Keyword:** sistema de pedidos online para restaurantes
- **Title:** Pedidos online para restaurantes (0% comisión) | FuturaDelivery
- **H1:** Pedidos directos para tu restaurante — 0% comisión

### (2) /delivery/precios/
- **Keyword:** plataforma delivery sin comisión precio
- **Title:** Precios | FuturaDelivery
- **H1:** Pagá una suscripción, quedate con tus ventas

### (3) /delivery/menu-qr/
- **Keyword:** menú digital QR para restaurantes
- **Title:** Menú digital QR para restaurantes | FuturaDelivery
- **H1:** Menú QR que se actualiza sin reimprimir

### (4) /delivery/pedidos-por-whatsapp/
- **Keyword:** pedidos por WhatsApp restaurante
- **Title:** Pedidos por WhatsApp para restaurantes | FuturaDelivery
- **H1:** Convertí WhatsApp en tu canal de pedidos

### (5) /delivery/alternativas-pedidosya/
- **Keyword:** alternativas a PedidosYa para restaurantes
- **Title:** Alternativas a PedidosYa: cómo vender sin comisiones
- **H1:** Menos comisión, más margen

### (6) /delivery/industrias/pizzerias/
- **Keyword:** pedidos online para pizzería
- **Title:** Pedidos online para pizzerías | FuturaDelivery
- **H1:** Pizzas y combos: subí ticket promedio

### (7) /delivery/industrias/heladerias/
- **Keyword:** pedidos online para heladerías
- **Title:** Pedidos online para heladerías | FuturaDelivery
- **H1:** Delivery propio para helado sin perder margen

### (8) /delivery/comparativas/futuradelivery-vs-pedidosya/
- **Keyword:** FuturaDelivery vs PedidosYa
- **Title:** FuturaDelivery vs PedidosYa (comisión vs canal propio)
- **H1:** Qué conviene según tu volumen

---

## 23.3 FuturaFitness — blueprints (8)

### (1) /fitness/software-para-personal-trainer/
- **Keyword:** software para personal trainer
- **Title:** Software para personal trainers | Rutinas + nutrición con IA
- **H1:** Tu sistema para gestionar alumnos (sin perder tiempo)

### (2) /fitness/precios/
- **Keyword:** precio app para entrenadores
- **Title:** Precios | FuturaFitness
- **H1:** Planes para entrenadores

### (3) /fitness/ia-rutinas/
- **Keyword:** IA para crear rutinas
- **Title:** IA para rutinas (con control profesional) | FuturaFitness
- **H1:** Creá rutinas en minutos, revisá en segundos

### (4) /fitness/planes-nutricionales/
- **Keyword:** plan nutricional personalizado app
- **Title:** Planes nutricionales personalizados | FuturaFitness
- **H1:** Nutrición para tus alumnos con macros y objetivos

### (5) /fitness/gamificacion/
- **Keyword:** gamificación fitness
- **Title:** Gamificación para retener alumnos | FuturaFitness
- **H1:** Desafíos, puntos y hábitos (retención)

### (6) /fitness/seguimiento-clientes/
- **Keyword:** seguimiento de progreso personal trainer
- **Title:** Seguimiento de progreso para entrenadores | FuturaFitness
- **H1:** Medí adherencia y resultados

### (7) /fitness/comparativas/futurafitness-vs-trainerize/
- **Keyword:** FuturaFitness vs Trainerize
- **Title:** FuturaFitness vs Trainerize: qué conviene
- **H1:** IA + gamificación vs plataforma tradicional

### (8) /fitness/recursos/plantillas-entrenadores/
- **Keyword:** plantillas para personal trainer
- **Title:** Plantillas para personal trainers (descargables)
- **H1:** Plantillas para seguimiento, rutinas y check-ins

---

## 23.4 Servicios IA — blueprints (6)

### (1) /servicios/chatbots/
- **Keyword:** chatbot para empresas Argentina
- **Title:** Chatbots para empresas en Argentina | Futura Sistemas
- **H1:** Automatizá atención y ventas 24/7

### (2) /servicios/chatbot-whatsapp/
- **Keyword:** chatbot WhatsApp para negocios
- **Title:** Chatbot WhatsApp Business | Implementación y casos
- **H1:** WhatsApp automatizado (sin perder el tono humano)

### (3) /servicios/asistentes-virtuales/
- **Keyword:** asistente virtual IA para empresas
- **Title:** Asistentes virtuales con IA (agentes) | Futura
- **H1:** Respuestas, derivación y workflows

### (4) /servicios/automatizacion-procesos/
- **Keyword:** automatización de procesos pymes
- **Title:** Automatización de procesos para pymes | RPA + IA
- **H1:** Menos tareas repetitivas, más control

### (5) /servicios/n8n/
- **Keyword:** automatización con n8n
- **Title:** Automatizaciones con n8n (self-hosted) | Futura
- **H1:** Workflows a medida (con integraciones)

### (6) /servicios/videovigilancia-ia/
- **Keyword:** videovigilancia con inteligencia artificial
- **Title:** Videovigilancia con IA | Detección y alertas
- **H1:** Seguridad inteligente (sin falsos positivos)

---

# Nota final
Este documento está diseñado para pasar de 0 SEO a un programa completo: **indexación + arquitectura + keywords + contenido + enlaces**.

**Lo más importante:** sin HTML pre-renderizado (SSG/SSR) y sin metadatos + sitemap + schema, la investigación de keywords no se transforma en tráfico.

**Siguiente paso recomendado (operativo):** convertir este plan en una planilla de ejecución (backlog) y asignar responsable/fecha por item. Luego, empezar por FuturaCRM (indexación + pilar + 2 posts) para obtener señales rápidas en GSC.