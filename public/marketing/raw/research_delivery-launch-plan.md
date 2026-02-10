# 🍔 FuturaDelivery — Marketing Launch Plan

**Project:** FuturaDelivery (El Braserito)  
**URL:** https://futuradelivery.vercel.app  
**Type:** Multi-tenant restaurant SaaS (digital menu, delivery, orders, kitchen display)  
**Market:** Argentine restaurants, food trucks, dark kitchens  
**Readiness Score:** 8.0/10 — CLOSEST TO LAUNCH  
**Created:** 2026-02-06

---

## 1. 📅 Launch Timeline — 8-Week Plan

### Week 1: Foundation & Fixes
- [ ] Fix fake social proof on landing page (remove "+500 restaurantes" claim)
- [ ] Rotate all exposed credentials (CREDENTIAL_ROTATION_GUIDE.md)
- [ ] Fix hardcoded storage key in AuthCallback.tsx
- [ ] Record 3 demo videos: (1) Setup in 5 min, (2) Kitchen workflow, (3) MercadoPago connection
- [ ] Create unified Instagram presence @futurasistemas.com.ar
- [ ] Secure handles: Twitter @futuradelivery, Facebook page, TikTok

### Week 2: Content Creation & Beta Recruitment
- [ ] Design 10 Instagram carousel posts showing features + templates
- [ ] Create Product Hunt "Coming Soon" page
- [ ] Write 3 blog posts for launch: "Cómo digitalizar tu restaurante en 2026", "Carta digital vs menú en papel", "Cómo aceptar pedidos online con MercadoPago"
- [ ] Recruit 5-10 real restaurants (friends/family/local in Pergamino) as beta testers
- [ ] Join 10+ Facebook groups: "Gastronómicos Argentinos", "Emprendedores Gastronómicos", etc.

### Week 3: Soft Launch & Beta Onboarding
- [ ] Personally onboard each beta restaurant (screen share, setup assistance)
- [ ] Collect testimonials and screenshots from real restaurant menus
- [ ] Start posting on Instagram: 3 posts/week + daily stories
- [ ] Share value content in Facebook gastronomy groups (no direct promo yet)
- [ ] Set up PostHog analytics + Sentry error tracking

### Week 4: Product Hunt Launch 🚀
- [ ] Launch on Product Hunt (Tuesday)
- [ ] Execute full launch day protocol (see Section 2)
- [ ] Post on Reddit: r/SaaS, r/SideProject, r/restaurateur
- [ ] Post on Indie Hackers: "Show IH" format
- [ ] WhatsApp outreach to 50+ restaurant contacts
- [ ] Start Instagram/Facebook ad campaigns ($100/week)

### Week 5: Post-Launch Momentum
- [ ] Analyze Product Hunt results (visitors, sign-ups, conversions)
- [ ] Follow up with EVERY sign-up personally (WhatsApp or email)
- [ ] Share launch results + testimonials on social media
- [ ] Submit to secondary directories: BetaList, SaaSHub, AlternativeTo, Capterra, ComparaSoftware.com.ar
- [ ] Write "Cómo lancé FuturaDelivery" retrospective thread on Twitter

### Week 6: Paid Ads & Partnerships
- [ ] Launch Google Ads: "software restaurante", "gestión delivery", "carta digital QR"
- [ ] Scale Instagram/Facebook ads based on Week 4-5 data
- [ ] Contact 5 food micro-influencers (5k-20k followers) for reviews
- [ ] Reach out to MercadoPago partner program for featured merchant status
- [ ] Start referral program: "Invitá a un colega, ambos reciben 1 mes gratis"

### Week 7: Content & SEO
- [ ] Publish comparison articles: "FuturaDelivery vs QueRestó", "FuturaDelivery vs Qamarero"
- [ ] Create YouTube tutorial: "Cómo crear tu carta digital en 5 minutos"
- [ ] Optimize landing page SEO: title tags, meta descriptions, H1s
- [ ] Submit sitemap to Google Search Console
- [ ] Guest post pitch to Argentine gastronomy blogs

### Week 8: Scale & Optimize
- [ ] Review all metrics: CAC, conversion rate, churn, MRR
- [ ] Kill underperforming ad sets, double down on winners
- [ ] Plan expansion: explore Uruguay/Chile restaurant markets
- [ ] Launch "Pro" features teaser for upcoming analytics module
- [ ] Set monthly marketing cadence for ongoing growth

---

## 2. 🏹 Product Hunt Strategy

### Listing Details

**Product Name:** FuturaDelivery  
**Tagline:** "Tu carta digital con pedidos y cocina en 5 minutos 🇦🇷"  
**Description:**
> FuturaDelivery is a complete restaurant management platform built for Argentina. Create a beautiful digital menu with 5 customizable templates, accept online orders with MercadoPago integration, and manage your kitchen in real-time with our Kitchen Display System. Set up your restaurant in under 5 minutes — no coding, no commissions, just a monthly subscription. Designed for restaurants, food trucks, and dark kitchens across Latin America.

**Maker's Comment:**
> 👋 Hey PH! I'm Gonzalo from Pergamino, Argentina. I built FuturaDelivery because I saw local restaurants struggling with expensive delivery platforms that take 30%+ commissions. Most alternatives are either too complex or too basic.
>
> FuturaDelivery gives you:
> - 🎨 5 beautiful menu templates (no designer needed)
> - 📱 QR code menus your customers scan at the table
> - 🛒 Online ordering with MercadoPago (Argentina's #1 payment platform)
> - 👨‍🍳 Kitchen Display System so your cooks never miss an order
> - 👥 Team management with roles (owner, admin, kitchen, staff)
>
> Built with React + Supabase + Edge Functions. The Kitchen Display updates in real-time via WebSocket — when a customer places an order, the kitchen sees it instantly.
>
> Pricing starts at ~$8 USD/month (ARS 9,990) with a 7-day free trial. No commissions ever.
>
> I'd love your feedback! What features would make this a must-have for your favorite local restaurant?

**Hunt Day:** Tuesday (highest Product Hunt engagement)  
**Launch Time:** 12:00 AM PST / 4:00 AM ART (automatic PH launch)  

### Assets to Prepare
1. **Hero image:** 1270×760px showing landing page + phone mockup with menu
2. **Gallery images (5):**
   - Menu template showcase (all 5 templates)
   - Kitchen Display System in action
   - Dashboard with order metrics
   - MercadoPago checkout flow
   - Mobile customer ordering experience
3. **Demo video:** 90-second walkthrough: create account → set up menu → receive order → kitchen display
4. **Thumbnail:** 240×240px FuturaDelivery logo

### Pre-Launch Engagement (2 weeks before)
- Follow 50+ active Product Hunt community members
- Comment genuinely on 5+ daily launches
- Share the "Coming Soon" link with email list and social followers
- Ask 20-30 supporters to follow the PH page (genuine, not vote-farming)

**Target:** 200+ upvotes, Top 10 Product of the Day

---

## 3. 📱 Social Media Plan

### Platform Priority

| Platform | Priority | Posting Frequency | Content Focus |
|----------|----------|-------------------|---------------|
| **Instagram** | ✅✅ Primary | 5x/week + daily Stories | Demos, food aesthetics, before/after, testimonials |
| **Facebook** | ✅✅ Primary | 3x/week + Groups daily | Community engagement, case studies, longer posts |
| **TikTok** | ✅ Active | 3x/week | 30-60s demos, "POV tu restaurante digital", food content |
| **Twitter/X** | ✅ Active | 5x/week | Build in public, milestones, quick updates |
| **LinkedIn** | ✅ Active | 3x/week | B2B angle, entrepreneurship, restaurant industry insights |
| **YouTube** | ⚡ Opportunistic | 1x/week | Tutorials, deep dives, setup guides |

### Weekly Content Calendar

| Day | Instagram | Facebook | TikTok | Twitter/X | LinkedIn |
|-----|-----------|----------|--------|-----------|----------|
| **Lunes** | Carousel: Feature spotlight | Group post: industry insight | Reel: Quick tip | Build update | Industry insight |
| **Martes** | Reel: Demo video | Case study post | — | Milestone share | — |
| **Miércoles** | Story: Poll/Q&A | Group engagement | Reel: Before/after | Lesson learned | B2B case study |
| **Jueves** | Carousel: Template showcase | — | — | Quick update | — |
| **Viernes** | Reel: Kitchen Display demo | Community post | Reel: "POV" format | Week recap thread | Achievement post |
| **Sábado** | Story: Behind the scenes | — | — | — | — |
| **Domingo** | — | — | — | — | — |

### Content Pillars
1. **Product Demos** (40%) — Show features in action, template previews, order flow
2. **Restaurant Stories** (25%) — Testimonials, before/after digitalization stories
3. **Industry Education** (20%) — Tips for restaurant owners, delivery trends
4. **Behind the Scenes** (15%) — Build in public, founder journey, technical decisions

### Hashtag Strategy (Instagram)
Primary: #cartadigital #menuqr #restaurantesargentina #gastroarg
Secondary: #emprendedoresgastronomicos #delivery #gestionrestaurante #comidaargentina
Niche: #darkitchen #foodtruck #pergamino #pymegastro

---

## 4. 📢 Instagram/Facebook Ads

### Campaign Structure

#### Campaign 1: Awareness (Top of Funnel)
**Objective:** Reach / Video Views  
**Target Audience:**
- Location: Argentina (all provinces)
- Age: 25-55
- Interests: Gastronomía, PedidosYa, Rappi, emprendimiento gastronómico, restaurant management
- Behaviors: Small business owners, restaurant page admins
- Exclude: Current app users

**Ad Copy (Spanish):**
> **Headline:** Tu restaurante digital en 5 minutos
> **Primary text:** ¿Todavía imprimís tu carta en papel? 📄➡️📱 Con FuturaDelivery creás tu menú digital, recibís pedidos online y gestionás tu cocina desde una sola plataforma. Sin comisiones. Desde $9.990/mes. Probalo gratis 7 días.
> **CTA:** Probar gratis

**Ad Format:** Video (30s demo showing menu creation + first order)  
**Budget:** $30 USD/week ($150/month)

#### Campaign 2: Conversion (Bottom of Funnel)
**Objective:** Conversions (Sign-up)  
**Target Audience:**
- Retarget: Website visitors (last 30 days) who didn't sign up
- Lookalike: 1% lookalike of current sign-ups
- Interest layering: "Facturación electrónica" + "MercadoPago" + "Emprendimiento"

**Ad Copy (Spanish):**
> **Headline:** ¿Por qué seguir pagando comisiones?
> **Primary text:** Los grandes delivery te cobran hasta 30% por pedido. Con FuturaDelivery pagás solo $9.990/mes — sin comisiones. Tu carta digital, tus pedidos, tu cocina. Todo en un solo lugar. 🍔🎯 7 días gratis, sin tarjeta.
> **CTA:** Registrarme gratis

**Ad Format:** Carousel (5 slides: each template + pricing)  
**Budget:** $50 USD/week ($200/month)

#### Campaign 3: Retargeting
**Objective:** Conversions  
**Target Audience:**
- Website visitors who viewed pricing page but didn't convert
- Trial users who didn't upgrade

**Ad Copy (Spanish):**
> **Headline:** Tu prueba gratis te espera
> **Primary text:** Ya viste lo que FuturaDelivery puede hacer por tu restaurante. ¿Qué estás esperando? 7 días gratis, sin compromiso. Activá tu carta digital hoy. 👨‍🍳
> **CTA:** Empezar ahora

**Budget:** $20 USD/week ($80/month)

### Total Monthly Ad Budget: $430 USD (~$516,000 ARS)

### KPIs to Track
| Metric | Target Month 1 | Target Month 3 |
|--------|---------------|---------------|
| Impressions | 100,000 | 500,000 |
| Clicks | 2,000 | 8,000 |
| CPC | $0.10-$0.20 USD | $0.08-$0.15 USD |
| Sign-ups from ads | 100 | 400 |
| Cost per sign-up | $4.30 USD | $3.00 USD |
| Trial → Paid conversion | 10% | 15% |

---

## 5. 🔍 SEO Keywords

| # | Keyword (Spanish) | Est. Monthly Searches | Difficulty | Priority |
|---|-------------------|----------------------|------------|----------|
| 1 | carta digital restaurante | 1,200-1,800 | Medium | 🔴 High |
| 2 | menú digital QR | 800-1,200 | Medium | 🔴 High |
| 3 | software para restaurantes argentina | 400-600 | Low | 🔴 High |
| 4 | sistema de pedidos online restaurante | 300-500 | Low | 🔴 High |
| 5 | gestión de delivery | 200-400 | Low | 🟡 Medium |
| 6 | cómo crear carta digital gratis | 500-800 | Medium | 🟡 Medium |
| 7 | alternativa pedidosya para restaurantes | 100-200 | Very Low | 🟡 Medium |
| 8 | cocina display sistema | 50-100 | Very Low | 🟢 Low |
| 9 | plataforma pedidos restaurante sin comisiones | 100-200 | Very Low | 🟡 Medium |
| 10 | menú QR mercadopago | 50-150 | Very Low | 🟢 Low |

### SEO Content Strategy
- **Landing page:** Target #1, #2, #4 in title/H1/meta
- **Blog post 1:** "Cómo crear tu carta digital gratis en 2026" → Target #6
- **Blog post 2:** "FuturaDelivery vs PedidosYa: ¿cuál conviene para tu restaurante?" → Target #7
- **Blog post 3:** "Qué es un Kitchen Display System y por qué tu restaurante lo necesita" → Target #8
- **FAQ page:** Target long-tail "People Also Ask" queries

---

## 6. ⚔️ Competitive Positioning

### Key Competitors

| Competitor | Price | Weakness | FuturaDelivery Advantage |
|-----------|-------|----------|--------------------------|
| **QueRestó** | Freemium | Basic menus only, no kitchen display | Full order + kitchen management |
| **Recafy** | Freemium | Allergen focus, no delivery integration | Complete delivery workflow |
| **DigitalizaTuMenu** | Free | Very limited features | 5 templates, MercadoPago, team roles |
| **CartaDigital Gratis** | Free | Buenos Aires only | Nationwide + multi-tenant |
| **Qamarero** | From €9.99/mo | Spain-based, expensive for Argentina | Argentina-first, ARS pricing, 3x cheaper |
| **Fudo** | From ~$30 USD/mo | Complex, expensive | Simpler UX, 4x cheaper |
| **PedidosYa** | 30% commission | Commission per order | Zero commissions, flat monthly fee |

### Positioning Statement
> **FuturaDelivery es la primera plataforma completa para restaurantes argentinos.** Carta digital + pedidos online + cocina en tiempo real, todo en un solo lugar. Sin comisiones, sin contratos, sin sorpresas. Desde $9.990/mes con MercadoPago.

### Differentiation Matrix

| Feature | FuturaDelivery | QueRestó | Fudo | Qamarero |
|---------|---------------|----------|------|----------|
| Digital menu | ✅ 5 templates | ✅ Basic | ✅ | ✅ |
| Online ordering | ✅ | ❌ | ✅ | ✅ |
| Kitchen Display | ✅ Real-time | ❌ | ✅ | ❌ |
| MercadoPago native | ✅ | ❌ | 🟡 Third-party | ❌ |
| ARS pricing | ✅ | ✅ | ❌ USD | ❌ EUR |
| Zero commissions | ✅ | ✅ | ❌ | ❌ |
| Team roles | ✅ 4 roles | ❌ | ✅ | 🟡 |
| Price | $9.990/mes | Free (limited) | ~$36k/mes | ~$15k/mes |

---

## 7. 💰 Pricing Recommendation

### Tier Structure (ARS with MercadoPago)

| Plan | Price/Month | Annual Price | Features |
|------|------------|-------------|----------|
| **Gratis** | $0 | — | 50 orders/month, 1 template, basic menu, no kitchen display |
| **Emprendedor** | $9,990 ARS (~$8 USD) | $99,900/year (save 2 months) | Unlimited orders, 5 templates, kitchen display, team (3 users) |
| **Profesional** | $19,990 ARS (~$17 USD) | $199,900/year (save 2 months) | Everything + analytics, priority support, custom domain |
| **Multi-Local** | $39,990 ARS (~$33 USD) | $399,900/year (save 2 months) | Multiple locations, API access, white-label option |

### Launch Special
- **Founding Member Deal:** $4,990 ARS/month ($5 USD) locked for life — first 50 restaurants
- **Product Hunt Special:** 50% off first 3 months for PH visitors

### Payment Methods (MercadoPago)
- Credit card (up to 12 cuotas sin interés)
- Debit card
- MercadoPago balance
- Bank transfer
- Cash via RapiPago/PagoFácil

---

## 8. 🚀 Growth Hacks

### Hack #1: "Escaneá y Pedí" QR Table Tents
**What:** Offer free physical QR code table tent templates (PDF) that restaurants can print.  
**Why:** Every QR scan by a diner is a brand impression. The menu footer shows "Powered by FuturaDelivery" with a sign-up link.  
**Cost:** $0 (PDF template)  
**Expected impact:** Each restaurant generates 50-200 scans/month, each scan shows the brand. Viral loop: diners who own restaurants see it → sign up.

### Hack #2: MercadoPago "Tienda Oficial" Partnership
**What:** Apply to be listed in MercadoPago's partner directory as a "Solución para Restaurantes." Contact MP's developer relations team.  
**Why:** Restaurants searching for MercadoPago-compatible tools will discover FuturaDelivery organically. MP actively promotes its ecosystem partners.  
**Cost:** $0 (relationship-building)  
**Expected impact:** 100-500 organic sign-ups/month from MercadoPago's traffic.

### Hack #3: "Digitalización Gratuita" Local Blitz
**What:** Offer to digitalize 20 restaurants in Pergamino for FREE (set up their menus, take food photos, configure the system). Document the process on video.  
**Why:** Creates 20 real case studies with before/after stories. Creates local buzz and word-of-mouth. Content from each digitalization = 5-10 social media posts. The restaurants become advocates.  
**Cost:** ~20 hours of labor  
**Expected impact:** 20 paying restaurants within 60 days (after free trial), 50+ social media content pieces, local media coverage potential.

---

## 📊 Marketing KPIs Dashboard

| Metric | Month 1 | Month 3 | Month 6 |
|--------|---------|---------|---------|
| Registered tenants | 50 | 200 | 500 |
| Paid subscribers | 5 | 30 | 100 |
| MRR (ARS) | $49,950 | $299,700 | $999,000 |
| MRR (USD) | ~$42 | ~$250 | ~$833 |
| Instagram followers | 500 | 2,000 | 5,000 |
| Monthly active orders | 200 | 2,000 | 10,000 |
| Website traffic | 3,000 | 15,000 | 50,000 |
| CAC (Customer Acquisition Cost) | $8 USD | $5 USD | $3 USD |
| Trial → Paid conversion | 10% | 15% | 20% |
| Monthly churn | 10% | 7% | 5% |

---

*Plan created: 2026-02-06 | Based on MARKETING_PLAYBOOK.md + futuradelivery-review.md*
