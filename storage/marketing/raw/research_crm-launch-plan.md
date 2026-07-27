# 🏪 FuturaCRM — Marketing Launch Plan

**Project:** FuturaCRM  
**Type:** B2B SaaS — invoicing, inventory, POS, CRM, webshop, AFIP integration  
**Market:** Small/medium Argentine businesses  
**Readiness Score:** 7.5/10  
**Created:** 2026-02-06

---

## 1. 📅 Launch Timeline — 8-Week Plan

### Week 1: Critical Fixes & Foundation
- [ ] Remove `VITE_SUPABASE_SERVICE_ROLE_KEY` from client env files
- [ ] Fix `OrderDetailPage` — replace mock data with real Supabase query
- [ ] Fix `fixDuplicateCustomers()` running on every app mount
- [ ] Set up PostHog analytics + Sentry error tracking
- [ ] Secure social handles: @futuracrm on Instagram, Twitter, Facebook, TikTok

### Week 2: Beta Recruitment & Content
- [ ] Recruit 5-10 small businesses from existing network (Pergamino/Buenos Aires)
- [ ] Create Product Hunt "Coming Soon" page
- [ ] Write 3 launch blog posts: "Facturación electrónica AFIP para PyMEs", "Cómo elegir un sistema de ventas", "FuturaCRM vs HubSpot: comparación honesta"
- [ ] Record 3 demo videos: (1) POS demo, (2) AFIP invoice flow, (3) Webshop setup
- [ ] Design 10 Instagram/LinkedIn carousel posts

### Week 3: Private Beta Launch
- [ ] Personally onboard each beta business
- [ ] Configure cron jobs for existing Edge Functions (trial reminders, token refresh)
- [ ] Test AFIP integration end-to-end with beta users
- [ ] Collect testimonials and screenshots from real businesses
- [ ] Start posting on LinkedIn: 4x/week (personal profile)

### Week 4: Product Hunt Launch 🚀
- [ ] Launch on Product Hunt (Wednesday — B2B does well midweek)
- [ ] Execute full launch day protocol
- [ ] Post on Reddit: r/SaaS, r/B2BSaaS, r/smallbusiness, r/argentina
- [ ] Post on Indie Hackers
- [ ] LinkedIn launch post with behind-the-scenes story
- [ ] Email blast to collected beta waitlist

### Week 5: Accountant Partnership Push
- [ ] Identify 20 accountants/contadores in Pergamino/Buenos Aires area
- [ ] Offer free "Profesional" accounts to 10 accountants who recommend to clients
- [ ] Create "Programa de Contadores" landing page
- [ ] Submit to Argentine software directories: ComparaSoftware.com.ar, Capterra, GetApp
- [ ] Start Google Ads targeting AFIP-related keywords

### Week 6: Paid Advertising & Content Marketing
- [ ] Launch Instagram/Facebook ad campaigns ($150/week)
- [ ] Launch Google Ads for commercial keywords ($100/week)
- [ ] Publish comparison content: "FuturaCRM vs Colppy", "FuturaCRM vs Xubio"
- [ ] Create vertical-specific landing pages: tech repair shops, boutiques, food businesses
- [ ] Start referral program: "Referí un negocio, ambos reciben 1 mes gratis"

### Week 7: Scale & Vertical Targeting
- [ ] Launch dedicated campaign for tech repair shops (leveraging repair module)
- [ ] Contact PyME associations: CAME (Confederación Argentina de la Mediana Empresa)
- [ ] Guest post pitch to Argentine business blogs (iProfesional, Infobae PyMEs)
- [ ] YouTube channel: weekly tutorial series "Gestioná tu negocio con FuturaCRM"
- [ ] MercadoLibre integration marketing (unique differentiator)

### Week 8: Optimization & Planning
- [ ] Review all metrics: CAC, conversion rate, churn, MRR
- [ ] Optimize ad spend based on 4 weeks of data
- [ ] Plan Q2: WhatsApp chatbot for support, mobile app, advanced analytics
- [ ] Set ongoing marketing cadence
- [ ] Write Q1 retrospective for Indie Hackers / LinkedIn

---

## 2. 🏹 Product Hunt Strategy

### Listing Details

**Product Name:** FuturaCRM  
**Tagline:** "Facturación AFIP + inventario + webshop para PyMEs argentinas 🇦🇷"  
**Description:**
> FuturaCRM is the all-in-one business management platform built specifically for Argentine SMBs. It handles AFIP electronic invoicing (Factura A, B, C), inventory across multiple warehouses, a point-of-sale system, CRM, webshop with 4 templates, cash register management, and MercadoPago/MercadoLibre integration — all in one app.
>
> If you're running a small business in Argentina, you know the pain: Colppy for accounting, a separate POS, spreadsheets for inventory, WhatsApp for clients. FuturaCRM replaces them all.
>
> 25+ modules including: invoicing, POS, CRM, webshop, inventory, quotes, delivery notes, purchase orders, cash register, check management, expense tracking, discount codes, price lists, tech repair service, and analytics. All in Spanish, all with MercadoPago.

**Maker's Comment:**
> 👋 Hi PH! I'm Gonzalo from Argentina. I built FuturaCRM because I watched small business owners in my city juggle 5+ different tools just to invoice a customer, track inventory, and manage their online store.
>
> The Argentine market has unique challenges:
> - 🧾 AFIP electronic invoicing is MANDATORY — most global tools don't support it
> - 💱 Pricing in ARS with MercadoPago is essential (not Stripe)
> - 📦 Multi-warehouse inventory management for businesses that sell in-store and online
> - 🔧 We even built a tech repair module for phone/computer repair shops
>
> The platform has 25+ modules (!) including a full webshop with 4 templates. It's probably the most feature-rich business management tool built specifically for Argentina.
>
> 30-day free trial, no credit card required. Would love your feedback on what we should build next!

**Hunt Day:** Wednesday (B2B launches perform well midweek)  
**Target:** 150+ upvotes, Top 15 Product of the Day

---

## 3. 📱 Social Media Plan

### Platform Priority

| Platform | Priority | Posting Frequency | Content Focus |
|----------|----------|-------------------|---------------|
| **LinkedIn** | ✅✅ Primary | 4x/week (personal profile) | B2B case studies, AFIP tips, entrepreneur journey |
| **Instagram** | ✅ Active | 3x/week + Stories | Product demos, client stories, behind the scenes |
| **Facebook** | ✅ Active | 3x/week + Groups | PyME community engagement, longer educational posts |
| **Twitter/X** | ✅ Active | 5x/week | Build in public, metrics, quick updates, AFIP news |
| **YouTube** | ✅ Active | 1x/week | Tutorial series, deep dives, feature walkthroughs |
| **TikTok** | ⚡ Opportunistic | 2x/week | Quick tips: "Cómo hacer una factura en 30 segundos" |

### Content Pillars
1. **AFIP & Tax Education** (30%) — Make the mandatory easy: invoice types, tax obligations, compliance tips
2. **Product Demos** (30%) — POS in action, webshop templates, inventory management flows
3. **Business Stories** (20%) — Client testimonials, before/after digitalization, PyME success stories
4. **Founder Journey** (20%) — Build in public, milestones, technical decisions, lessons learned

### LinkedIn Content Strategy (Most Important Channel)
- **Monday:** Industry insight ("Las PyMEs argentinas pierden X horas/mes en facturación manual")
- **Tuesday:** Product feature highlight with screenshot
- **Wednesday:** Customer story or case study
- **Thursday:** Hot take or lesson learned ("Lo que aprendí lanzando un SaaS B2B en Argentina")
- Post from PERSONAL profile (not company page) — 5-10x more reach

---

## 4. 📢 Instagram/Facebook Ads

### Campaign 1: AFIP Compliance Angle (Awareness)
**Objective:** Reach / Video Views  
**Target Audience:**
- Location: Argentina (all provinces)
- Age: 25-55
- Interests: Facturación electrónica, AFIP, monotributo, contabilidad, PyME, emprendimiento
- Behaviors: Small business owners, page admins
- Job titles (Facebook): Contador, Administrador, Dueño

**Ad Copy (Spanish):**
> **Headline:** Facturación AFIP sin dolores de cabeza
> **Primary text:** ¿Cansado de pelear con el sistema de AFIP? 😤 Con FuturaCRM hacés facturas A, B y C en segundos. Inventario, clientes, ventas y webshop — todo en un solo lugar. Sin Excel, sin papel, sin estrés. Probalo 30 días gratis. 🧾✅
> **CTA:** Probar gratis

**Budget:** $60 USD/week ($240/month)

### Campaign 2: "Reemplazá 5 herramientas" (Conversion)
**Objective:** Conversions (Sign-up)  
**Target Audience:**
- Retarget: Website visitors (last 30 days)
- Interest layering: "MercadoLibre" + "MercadoPago" + "Software de gestión"
- Lookalike: 1% of sign-ups

**Ad Copy (Spanish):**
> **Headline:** 1 plataforma = 5 herramientas
> **Primary text:** Dejá de pagar por un CRM, un sistema de facturación, un POS, un inventario y una tienda online por separado. FuturaCRM es TODO eso, desde $14.990/mes. Facturación AFIP ✅ MercadoPago ✅ MercadoLibre ✅ Inventario multi-depósito ✅ Webshop con 4 plantillas ✅
> **CTA:** Registrarme gratis

**Ad Format:** Carousel (5 slides: one per replaced tool)  
**Budget:** $80 USD/week ($320/month)

### Campaign 3: Tech Repair Vertical
**Objective:** Conversions  
**Target Audience:**
- Location: Argentina (metros: Buenos Aires, Córdoba, Rosario, Mendoza)
- Interests: Reparación de celulares, servicio técnico, electrónica
- Custom audience: Followers of tech repair supply pages

**Ad Copy (Spanish):**
> **Headline:** Software para tu servicio técnico
> **Primary text:** ¿Reparás celulares o computadoras? FuturaCRM tiene un módulo especializado para vos: órdenes de reparación, seguimiento de equipos, repuestos, presupuestos y facturación AFIP. Todo en uno. 🔧📱
> **CTA:** Probar gratis 30 días

**Budget:** $40 USD/week ($160/month)

### Total Monthly Ad Budget: $720 USD (~$864,000 ARS)

---

## 5. 🔍 SEO Keywords

| # | Keyword (Spanish) | Est. Monthly Searches | Difficulty | Priority |
|---|-------------------|----------------------|------------|----------|
| 1 | facturación electrónica argentina | 2,000-3,000 | High | 🔴 High |
| 2 | sistema de ventas pyme | 800-1,200 | Medium | 🔴 High |
| 3 | software de facturación AFIP | 600-900 | Medium | 🔴 High |
| 4 | control de stock software | 1,000-1,500 | Medium | 🔴 High |
| 5 | CRM para pymes argentina | 300-500 | Low | 🟡 Medium |
| 6 | alternativa colppy | 200-400 | Very Low | 🟡 Medium |
| 7 | sistema punto de venta argentina | 500-800 | Medium | 🟡 Medium |
| 8 | tienda online mercadopago | 400-700 | Medium | 🟡 Medium |
| 9 | software servicio técnico celulares | 200-400 | Low | 🟢 Low (niche) |
| 10 | gestión de inventario multi depósito | 100-200 | Very Low | 🟢 Low (niche) |

### Content Strategy
- **Landing page SEO:** Target #1, #2, #3, #4 with separate feature pages
- **Blog post 1:** "Guía completa de facturación electrónica AFIP 2026" → Target #1 (high-volume evergreen)
- **Blog post 2:** "Los 5 mejores sistemas de ventas para PyMEs argentinas" (include self in list) → Target #2
- **Comparison pages:** "FuturaCRM vs Colppy" → Target #6
- **Vertical pages:** "/servicio-tecnico" → Target #9

---

## 6. ⚔️ Competitive Positioning

### Competitive Landscape

| Competitor | Price | Strength | Weakness | FuturaCRM Advantage |
|-----------|-------|----------|----------|------------------------|
| **HubSpot** | Free CRM / $15+/mo | Massive ecosystem | No AFIP, expensive at scale, English-first | AFIP native, ARS pricing, Spanish-first |
| **Colppy** | ~$15k ARS/mo | Deep AFIP integration, accounting | Accounting-focused, no POS/webshop/CRM | 25+ modules vs single-purpose |
| **Xubio** | ~$10k ARS/mo | Multi-country | Accounting-focused, no webshop | Full business management, not just accounting |
| **Zoho CRM** | Free/3 users, $14/user | Feature-rich | Not localized, no AFIP | Argentina-specific, MercadoPago native |
| **Tango Gestión** | Custom | Deep AR presence | Legacy software, dated UX | Modern cloud-native, responsive, PWA |
| **Bitrix24** | Free/5GB | All-in-one | Complex, buggy, not localized | Simpler UX, AFIP integration |

### Positioning Statement
> **FuturaCRM: el sistema de gestión más completo para PyMEs argentinas.** Facturación AFIP + inventario + POS + CRM + webshop + MercadoPago — todo en una sola plataforma. No necesitás 5 herramientas, necesitás una.

### Key Differentiators
1. **25+ modules in one platform** — No competitor offers POS + CRM + invoicing + webshop + inventory + repairs
2. **AFIP-native** — Built for Argentine tax requirements from day one
3. **MercadoPago + MercadoLibre** — The two platforms every Argentine business uses
4. **4 webshop templates** — Competitors don't include e-commerce
5. **Tech repair module** — Unique vertical-specific feature
6. **Price** — 50-70% cheaper than international alternatives

---

## 7. 💰 Pricing Recommendation

### Tier Structure (ARS with MercadoPago)

| Plan | Price/Month | Annual Price | Features |
|------|------------|-------------|----------|
| **Inicio** | $0 (free forever) | — | 50 products, 20 invoices/month, basic CRM, 1 user, no AFIP |
| **Profesional** | $14,990 ARS (~$12 USD) | $149,900/year (save 2 months) | Unlimited products, AFIP invoicing, POS, CRM, 1 user |
| **Negocio** | $29,990 ARS (~$25 USD) | $299,900/year (save 2 months) | Multi-user (5), webshop, multi-warehouse, purchase orders |
| **Enterprise** | $59,990 ARS (~$50 USD) | $599,900/year (save 2 months) | Unlimited users, API, MercadoLibre integration, priority support |

### Vertical-Specific Bundles
- **Pack Servicio Técnico:** Negocio plan + repair module activated = $29,990/month
- **Pack Tienda Online:** Negocio plan + webshop priority = $29,990/month  
  (No extra charge — these are "bundles" that market the same plan to different audiences)

### Launch Specials
- **Founding Member:** $7,490/month locked for life — first 30 businesses
- **Contador Referral:** Accountants who refer 5+ clients get permanent free Profesional account
- **Product Hunt:** 3 months at 50% off for PH visitors

### Payment Methods
- MercadoPago Checkout Pro (all methods)
- Credit card up to 12 cuotas sin interés
- Bank transfer (for Enterprise annual plans)

---

## 8. 🚀 Growth Hacks

### Hack #1: "Programa de Contadores" — Accountant Referral Network
**What:** Partner with accountants/contadores who advise Argentine SMBs. Give them a free Profesional account + 20% recurring revenue share for every client they refer.  
**Why:** Every contador in Argentina advises 20-100 small businesses. They're the #1 trusted advisor for "what software should I use for invoicing?" Making them ambassadors creates a scalable B2B channel.  
**Execution:**
1. Create "/contadores" landing page explaining the program
2. LinkedIn outreach to 50 contadores in Buenos Aires, Córdoba, Rosario
3. Offer free online training session: "Cómo ayudar a tus clientes con facturación digital"
4. Provide co-branded PDF guides they can share with clients  
**Cost:** $0 upfront (revenue share only)  
**Expected impact:** Each active contador refers 3-5 businesses/month → 50 contadores × 3 referrals = 150 new businesses/month

### Hack #2: "Migrá de Excel a FuturaCRM" — Free Data Import Service
**What:** Offer free data migration from Excel/Sheets to FuturaCRM for any business that signs up for a paid plan. Include: products, clients, price lists, inventory counts.  
**Why:** The #1 barrier to switching from Excel is "I have all my data there." Eliminating this friction converts hesitant prospects. Every migration creates a deeply invested customer (high switching cost = low churn).  
**Execution:**
1. Build a simple CSV import tool (products, clients, inventory)
2. Offer personal migration assistance (WhatsApp video call) for first 50 customers
3. Market as: "Pasá de Excel a FuturaCRM en 1 hora — nosotros hacemos la migración"  
**Cost:** ~2 hours per migration × 50 = 100 hours (first 50 customers)  
**Expected impact:** 2-3x higher conversion rate for prospects with existing Excel data. Near-zero churn for migrated customers.

### Hack #3: "AFIP Compliance Checker" — Free SEO Lead Magnet
**What:** Build a free, public-facing tool: "¿Tu negocio cumple con las regulaciones de facturación AFIP?" — a 5-question quiz that checks if a business is compliant with current AFIP electronic invoicing requirements.  
**Why:** High search volume for AFIP-related queries (#1 keyword: 2,000-3,000/month). The quiz captures email addresses and segments leads by urgency. Non-compliant businesses get a "FuturaCRM can fix this" CTA.  
**Execution:**
1. Create a standalone quiz page at optimized URL: "/verificar-afip"
2. 5 questions about business type, invoicing method, current tools
3. Result: "Cumplís ✅" or "Riesgo ⚠️" with specific recommendations
4. Email capture: "Recibí la guía completa de compliance AFIP 2026"  
**Cost:** ~8 hours to build  
**Expected impact:** 500-1,000 monthly visitors from SEO. 10-15% email capture rate = 50-150 leads/month.

---

## 📊 Marketing KPIs Dashboard

| Metric | Month 1 | Month 3 | Month 6 |
|--------|---------|---------|---------|
| Registered businesses | 30 | 150 | 400 |
| Paid subscribers | 5 | 25 | 80 |
| MRR (ARS) | $74,950 | $374,750 | $1,199,200 |
| MRR (USD) | ~$62 | ~$312 | ~$999 |
| Active contadores in program | 5 | 20 | 50 |
| LinkedIn followers | 300 | 1,500 | 4,000 |
| Website traffic | 2,000 | 10,000 | 35,000 |
| CAC | $12 USD | $8 USD | $5 USD |
| Trial → Paid conversion | 15% | 18% | 22% |
| Monthly churn | 8% | 5% | 4% |

---

*Plan created: 2026-02-06 | Based on MARKETING_PLAYBOOK.md + futuracrm-review.md*
