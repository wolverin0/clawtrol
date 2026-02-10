# 🚀 Futura Sistemas — Marketing Hub

## Quiénes Somos

**Futura Sistemas** es una empresa argentina de software que ofrece soluciones tecnológicas para empresas de todos los tamaños.

### Productos

| Producto | Target | Propuesta |
|----------|--------|-----------|
| **FuturaDelivery** | Gastronómicos, dark kitchens, meal prep | Delivery por suscripción. Carta digital QR. Sin comisiones. |
| **FuturaFitness** | Entrenadores, atletas, gimnasios | App de fitness con IA (Gemini). Rutinas, nutrición, progreso. |
| **FuturaCRM** | PyMEs argentinas | Facturación AFIP + inventario + POS + webshop + CRM. Todo en uno. |

### Servicios

| Servicio | Descripción |
|----------|-------------|
| **Implementaciones rápidas** | Setup de sistemas en días, no meses. Migración desde Excel/papel a digital. |
| **Migraciones de sistemas** | De sistemas legacy a plataformas modernas. Zero downtime. |
| **Integración con IA** | Gemini, GPT, Claude integrado a tu operación. Análisis predictivo. |
| **Asistentes virtuales** | Chatbots inteligentes para atención al cliente 24/7. WhatsApp, web, Telegram. |
| **Atendedores virtuales** | Recepción automatizada, triage de consultas, derivación inteligente. |
| **Video vigilancia con IA** | Integración de cámaras con detección de anomalías, alertas automáticas. |
| **Automatización de procesos** | n8n + IA para eliminar tareas manuales repetitivas. |

### Diferenciadores
- 🇦🇷 **Hecho en Argentina** — Entendemos el mercado local (AFIP, MercadoPago, regulaciones)
- ⚡ **Implementación rápida** — Días, no meses
- 🤖 **IA integrada nativamente** — No es un add-on, es parte del core
- 💰 **Sin comisiones abusivas** — Tu negocio, tus reglas
- 🔧 **Soporte real** — No tickets, personas

### Brand Guide
- **Colores primarios:** Deep navy (#0a1628) → Electric cyan (#00d4ff)
- **Colores por producto:**
  - Delivery: Orange (#F97316) + Navy (#1e293b)
  - Fitness: Cyan (#00d4ff) + Dark (#0a0a0a)
  - CRM: Blue (#3B82F6) + White
- **Tipografía:** Geométrica sans-serif (Futura/Inter/Geist)
- **Tono:** Profesional pero cercano. Técnico pero accesible. Argentino.
- **Evitar:** Jerga corporativa vacía, stock photos genéricas, promesas sin sustancia

## Estructura de Carpetas

```
marketing/
├── README.md               ← Este archivo
├── brand/                  ← Assets de marca, guía visual
├── content/                ← Contenido listo para publicar
│   ├── delivery/           ← Posts, stories, reels FuturaDelivery
│   ├── fitness/            ← Posts, stories, reels FuturaFitness
│   ├── crm/                ← Posts, stories, reels FuturaCRM
│   └── brand/              ← Posts de marca Futura Sistemas
├── calendar/               ← Calendarios de publicación
├── research/               ← Market intel, competitor analysis
├── prompts/                ← Prompts optimizados para image gen
├── generated/              ← Imágenes generadas (gpt-image-1, Nano Banana Pro)
│   ├── delivery/
│   ├── fitness/
│   ├── crm/
│   └── brand/
└── campaigns/              ← Campañas específicas (launches, promos)
```

## Herramientas

- **Image Gen:** gpt-image-1 (OpenAI) + Nano Banana Pro (Gemini web)
- **Publishing:** n8n workflows → Facebook Graph API
- **Approval:** Telegram bot → approve/reject → auto-publish
- **Analytics:** PostHog (web) + Meta Insights (social)
- **Page:** Futura Sistemas (FB ID: 908339149039975)

## Workflows n8n
- `Futura / FB Post (Futura Sistemas)` — Post directo
- `Futura / FB Post con Aprobación Telegram` — Con approval flow
- 5 templates importados (marketing/) — Meta Graph API, Telegram approval, multi-platform
