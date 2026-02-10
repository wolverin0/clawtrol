# 🏋️ FuturaFitness — Marketing Launch Plan

**Project:** FuturaFitness  
**Type:** B2C — Fitness tracking, workout plans, nutrition, AI-powered coaching  
**Market:** Argentine fitness enthusiasts, personal trainers, gym coaches  
**Stack:** React + Vite + Supabase + Gemini AI + MercadoPago  
**Readiness Score:** 6.0/10  
**Created:** 2026-02-06

---

## 1. 📅 Launch Timeline — 8-Week Plan

### Week 1: Critical Security Fixes
- [ ] Rotate ALL exposed credentials (Supabase, MercadoPago, Gemini)
- [ ] Add `.env` to `.gitignore` and scrub from git history
- [ ] Fix auth privilege escalation: change default role from `admin` to `null`
- [ ] Move globaladmin check to Supabase RLS (server-side)
- [ ] Move Gemini API calls to server-side proxy (Edge Function)
- [ ] Remove `window.planService` global exposure in production builds

### Week 2: Payment & Core Feature Fixes
- [ ] Implement MercadoPago IPN webhook for payment fulfillment
- [ ] Auto-activate subscriptions on successful payment
- [ ] Add "Forgot Password" flow
- [ ] Fix duplicate `Database` type in supabase/client.ts
- [ ] Remove duplicate payment pages and toast hooks
- [ ] Clean up console.log debug statements (30+ in AuthContext)

### Week 3: Testing & Polish
- [ ] Set up Vitest and add 20 critical path tests
- [ ] Add basic E2E tests with Playwright for auth + payment flows
- [ ] Remove unused Expo/React Native/Capacitor dependencies
- [ ] Set up PostHog analytics + Sentry error tracking
- [ ] Polish onboarding wizard flow
- [ ] Configure Vercel security headers

### Week 4: Content Creation & Social Media Setup
- [ ] Create unified Instagram presence @futurasistemas.com.ar
- [ ] Secure handles: TikTok @futurafitness, Twitter, YouTube
- [ ] Record 5 demo Reels/TikToks: AI routine generation, diet planning, progress tracking
- [ ] Create 10 Instagram carousel posts: features, benefits, comparisons
- [ ] Design "Free vs Pro" comparison graphic
- [ ] Create Product Hunt "Coming Soon" page

### Week 5: Beta Launch & Influencer Outreach
- [ ] Recruit 10-20 personal trainers as beta testers (offer free Pro for 6 months)
- [ ] Each beta trainer invites their clients → 50-100 student users
- [ ] Collect testimonials and screenshots from real coach/student workflows
- [ ] Contact 10 fitness micro-influencers (5k-20k followers) for reviews
- [ ] Start posting: Instagram 5x/week, TikTok 3x/week, Twitter 5x/week
- [ ] Join fitness-related Facebook groups in Argentina

### Week 6: Product Hunt Launch 🚀
- [ ] Launch on Product Hunt (Tuesday)
- [ ] Execute full launch day protocol
- [ ] Post on Reddit: r/fitness, r/personaltraining, r/SaaS, r/SideProject
- [ ] Post on Indie Hackers
- [ ] WhatsApp outreach to fitness contacts in Argentina
- [ ] Start Instagram/Facebook ad campaigns ($100/week)

### Week 7: Paid Ads & Growth
- [ ] Scale Instagram/Facebook ads based on Week 6 data
- [ ] Launch Google Ads for fitness app keywords
- [ ] Launch referral program: "Invitá a otro entrenador, obtené 1 mes gratis"
- [ ] Create YouTube tutorial: "Cómo digitalizar tu negocio de entrenamiento personal"
- [ ] Publish comparison content: "FuturaFitness vs Strong", "FuturaFitness vs Hevy"
- [ ] Contact gym chains for bulk licensing conversations

### Week 8: Optimization & Scale
- [ ] Review all metrics: downloads, sign-ups, conversions, churn
- [ ] Kill underperforming ad sets, double down on winners
- [ ] Plan PWA/mobile app enhancement (push notifications, offline mode)
- [ ] Plan wearable integrations (Apple Health, Google Fit, Garmin)
- [ ] Set ongoing marketing cadence
- [ ] Explore WhatsApp integration for coach-client communication

---

## 2. 🏹 Product Hunt Strategy

### Listing Details

**Product Name:** FuturaFitness  
**Tagline:** "AI-powered coaching platform for personal trainers — en español 🇦🇷🏋️"  
**Description:**
> FuturaFitness is a complete coaching platform for personal trainers and their clients. Create AI-powered workout routines and nutrition plans using Google Gemini, manage your client roster, track progress with measurements and photos, and gamify the fitness journey with points and achievements.
>
> Built for Latin American fitness professionals: 100% in Spanish, MercadoPago integration, local food database with 34,000+ Argentine foods, and coach-to-client workflow with invitation codes.
>
> Features: AI routine builder, AI diet planner, exercise library, progress photos, body measurements tracking, client management, workout logging with PRs and streaks, analytics dashboard, gamification system, and dark/light themes.

**Maker's Comment:**
> 👋 Hey PH! I'm Gonzalo from Argentina.
>
> I built FuturaFitness because every personal trainer I know manages their clients via WhatsApp messages and Excel spreadsheets. Send a routine via text, get a "👍" back, and hope they do it. No tracking, no data, no accountability.
>
> FuturaFitness changes that:
> - 🤖 **AI generates routines in 30 seconds** — Gemini AI creates personalized workout plans based on goals, equipment, and experience level
> - 🥗 **AI meal plans** with a database of 34,000+ Argentine foods (empanadas, asado, mate included 😄)
> - 📊 **Real progress tracking** — measurements, photos, workout logs, PRs
> - 🎮 **Gamification** — clients earn points, level up, unlock achievements
> - 📱 **Invitation codes** — trainers share a 6-digit code, clients join their roster
>
> 100% in Spanish. MercadoPago for subscriptions. Built for the Latin American fitness market.
>
> Free for trainers with up to 5 clients. Pro unlocks AI features and unlimited clients from ~$2.50 USD/month.
>
> Would love feedback from fitness professionals! What's missing?

**Hunt Day:** Tuesday  
**Target:** 200+ upvotes, Top 10 Product of the Day

---

## 3. 📱 Social Media Plan

### Platform Priority

| Platform | Priority | Posting Frequency | Content Focus |
|----------|----------|-------------------|---------------|
| **Instagram** | ✅✅ Primary | 5x/week + daily Stories + 3 Reels/week | Transformations, AI demos, workout tips, client success |
| **TikTok** | ✅✅ Primary | 5x/week | 30-60s demos, quick workout tips, AI routine generation clips |
| **Twitter/X** | ✅ Active | 5x/week | Build in public, milestones, fitness industry takes |
| **YouTube** | ✅ Active | 1-2x/week | Tutorials, platform walkthroughs, trainer interviews |
| **Facebook** | ⚡ Opportunistic | 2x/week + Groups | Fitness trainer communities, longer educational posts |
| **LinkedIn** | ⚡ Opportunistic | 2x/week | "Fitness as a business" angle, entrepreneur content |

### Content Pillars
1. **AI Magic Moments** (35%) — "Watch the AI create a full routine in 30 seconds" type content
2. **Fitness Education** (25%) — Workout tips, nutrition facts, exercise form guides
3. **Trainer Success Stories** (20%) — Beta tester testimonials, before/after business digitalization
4. **Product Demos** (20%) — Feature walkthroughs, "Did you know?" tips

### Instagram Reels Strategy (KEY GROWTH CHANNEL)
- **Format 1:** "POV: sos entrenador y tu cliente te pide una rutina" → show AI generating it
- **Format 2:** "Antes vs Después" → spreadsheet management vs FuturaFitness dashboard
- **Format 3:** "3 errores que cometen los entrenadores personales" → educational + soft sell
- **Format 4:** Time-lapse of building a full weekly routine with AI
- **Target hashtags:** #entrenadorpersonal #fitness #rutinagym #nutricion #IA #personaltrainer

### TikTok Strategy
- **Trending sounds** + fitness app demos = high viral potential
- **"Day in the life of a personal trainer using FuturaFitness"** format
- **"The AI said WHAT?"** — react to AI-generated meal plans (humorous angle)
- **Client transformation stories** (with permission)
- **Post timing:** 12-2 PM and 7-9 PM ART (peak Argentina TikTok hours)

---

## 4. 📢 Instagram/Facebook Ads

### Campaign 1: Personal Trainers (B2B2C)
**Objective:** Conversions (Trainer sign-ups)  
**Target Audience:**
- Location: Argentina (expand to LATAM in Week 8)
- Age: 22-45
- Interests: Personal training, fitness coaching, gym, CrossFit, exercise science
- Job titles: Entrenador personal, instructor de fitness, coach
- Behaviors: Fitness page admins, business page owners in fitness category

**Ad Copy (Spanish):**
> **Headline:** Dejá de mandar rutinas por WhatsApp
> **Primary text:** ¿Gestionás tus clientes con mensajes de texto y Excel? 😩 FuturaFitness es la plataforma profesional para entrenadores personales. La IA crea rutinas y planes nutricionales en segundos. Tus clientes trackean progreso, logran objetivos y te recomiendan. Probá gratis con hasta 5 clientes. 🏋️‍♂️
> **CTA:** Probar gratis

**Ad Format:** Reel (30s showing AI routine generation → client receiving it)  
**Budget:** $40 USD/week ($160/month)

### Campaign 2: Fitness Enthusiasts (B2C Direct)
**Objective:** Conversions (User sign-ups)  
**Target Audience:**
- Location: Argentina
- Age: 18-40
- Interests: Gym, fitness, workout, ejercicio, musculación, nutrición deportiva
- Behaviors: Fitness app users, gym check-in users
- Exclude: Personal trainers (separate campaign)

**Ad Copy (Spanish):**
> **Headline:** Tu entrenamiento, potenciado por IA
> **Primary text:** FuturaFitness genera rutinas personalizadas con inteligencia artificial según tus objetivos. Seguí tu progreso, registrá tus PRs, y motiváte con logros y puntos. 🎯 100% en español. Gratis para empezar. 💪
> **CTA:** Descargar gratis

**Ad Format:** Carousel (4 slides: AI routine, progress tracking, gamification, nutrition)  
**Budget:** $30 USD/week ($120/month)

### Campaign 3: Retargeting
**Objective:** Conversions (trial → paid)  
**Target Audience:**
- Website visitors who signed up but haven't subscribed
- Users who visited pricing page
- App users inactive >7 days

**Ad Copy (Spanish):**
> **Headline:** Tu plan Pro te espera
> **Primary text:** Ya probaste FuturaFitness y viste el poder de la IA. Ahora desbloqueá clientes ilimitados, planes nutricionales avanzados y analytics completos. Desde $2.990/mes — menos que un café por día. ☕→🏋️
> **CTA:** Activar Pro

**Budget:** $20 USD/week ($80/month)

### Total Monthly Ad Budget: $360 USD (~$432,000 ARS)

---

## 5. 🔍 SEO Keywords

| # | Keyword (Spanish) | Est. Monthly Searches | Difficulty | Priority |
|---|-------------------|----------------------|------------|----------|
| 1 | app para entrenadores personales | 500-800 | Low | 🔴 High |
| 2 | software para entrenador personal | 200-400 | Very Low | 🔴 High |
| 3 | app de rutinas de gym | 2,000-3,500 | High | 🟡 Medium |
| 4 | plan de entrenamiento con IA | 300-600 | Low | 🔴 High |
| 5 | app ejercicios en español | 800-1,200 | Medium | 🟡 Medium |
| 6 | gestión de clientes fitness | 100-200 | Very Low | 🔴 High (niche) |
| 7 | tracker de entrenamiento | 500-800 | Medium | 🟡 Medium |
| 8 | plan nutricional personalizado app | 400-700 | Medium | 🟡 Medium |
| 9 | alternativa strong app español | 100-200 | Very Low | 🟢 Low (easy) |
| 10 | cómo gestionar clientes como entrenador personal | 200-400 | Very Low | 🔴 High (intent) |

### SEO Content Strategy
- **Landing page:** Target #1, #2, #4 in title/H1/meta description
- **Blog post 1:** "Las 5 mejores apps para entrenadores personales en 2026" (include FuturaFitness) → Target #1
- **Blog post 2:** "Cómo usar inteligencia artificial para crear rutinas de gym" → Target #4
- **Blog post 3:** "FuturaFitness vs Strong: comparación completa en español" → Target #9
- **Blog post 4:** "Guía completa: cómo gestionar clientes como entrenador personal" → Target #10
- **FAQ page:** Target long-tail "People Also Ask" queries around fitness apps

---

## 6. ⚔️ Competitive Positioning

### Competitive Landscape

| Competitor | Price | Strength | Weakness | FuturaFitness Advantage |
|-----------|-------|----------|----------|----------------------|
| **Hevy** | Free / Pro $2.99/mo | Social features, huge exercise library | English-first, community focus over coaching | Spanish-first, coach/client workflow |
| **Strong** | Free (3 routines) / Pro $4.99/mo | Clean UI, Apple Watch | Limited free tier, no AI, English | Generous free tier, AI-powered, Spanish |
| **Fitbod** | $12.99/mo | AI workouts, personalized | Very expensive, English only | 5x cheaper, Spanish, coach model |
| **FitNotes** | Free (Android only) | Completely free | Android only, no cloud sync, dated UI | Cross-platform, cloud-synced, modern |
| **Setgraph** | Free / Pro TBD | Speed-focused logging | Very new, niche | Broader features, AI, nutrition |
| **TrainerRoad** | $189/year | Advanced training plans | Cycling only, expensive | Multi-sport, affordable, Spanish |
| **TrueCoach** | $19/mo+ | Excellent coach platform | Very expensive, English | 6x cheaper, Spanish, AI-powered |

### Positioning Statement
> **FuturaFitness: la plataforma de coaching fitness más completa en español.** Rutinas con IA, planes nutricionales personalizados, seguimiento de progreso y gamificación — todo en un solo lugar. Para entrenadores que quieren profesionalizarse y clientes que quieren resultados.

### Key Differentiators
1. **Spanish-first** — The only serious fitness coaching platform 100% in español
2. **AI-powered** — Gemini AI generates routines AND nutrition plans in seconds
3. **Coach + Client model** — Not just a tracker; it's a relationship management tool
4. **Argentine food database** — 34,000+ local foods (empanadas, milanesas, choripán!)
5. **Gamification** — Points, levels, achievements keep clients engaged
6. **MercadoPago** — Trainers can charge clients through the platform
7. **Price** — 5-10x cheaper than international coaching platforms

---

## 7. 💰 Pricing Recommendation

### Tier Structure (ARS with MercadoPago)

| Plan | Price/Month | Annual Price | Features |
|------|------------|-------------|----------|
| **Gratis** | $0 | — | 5 clients, 10 routines, basic tracking, no AI, no nutrition |
| **Profesional** | $4,990 ARS (~$4 USD) | $49,900/year (save 2 months) | 50 clients, AI routines, AI nutrition, progress photos, analytics |
| **Elite** | $9,990 ARS (~$8 USD) | $99,900/year (save 2 months) | Unlimited clients, advanced analytics, white-label option, priority support |

### USD Pricing (Global/Non-LATAM)
| Plan | Price/Month | Annual |
|------|------------|--------|
| **Free** | $0 | — |
| **Pro** | $4.99 USD | $49.99/year |
| **Elite** | $9.99 USD | $99.99/year |

### Launch Specials
- **Founding Trainer:** $1,990 ARS/month locked for life — first 50 trainers
- **Product Hunt:** Free Profesional for 3 months (no credit card)
- **Lifetime Deal:** $29 USD lifetime Profesional access (first 100 buyers)
- **Bulk Gym Deal:** 10+ trainers from same gym = 40% discount on all subscriptions

### Revenue Model
- **Subscriptions** (primary): Trainer and student Pro plans
- **Coach Payment Processing** (future): Take 5% fee when trainers charge clients through FuturaFitness
- **Marketplace** (future): Connect trainers with clients seeking coaches (commission model)

---

## 8. 🚀 Growth Hacks

### Hack #1: "Rutina Gratis con IA" — Viral Landing Page
**What:** Build a standalone, public-facing page where ANYONE (no login required) can input their fitness goals, available equipment, and time per session — and the AI generates a complete weekly routine. Share results on Instagram/WhatsApp with "Creado con FuturaFitness" watermark.  
**Why:** AI + fitness is inherently shareable content. People love sharing their personalized routines. Each shared routine = organic brand awareness. The call-to-action is "¿Querés más? Registrate gratis para guardar tu rutina y trackear tu progreso."  
**Execution:**
1. Create `/rutina-gratis` public page with simple form
2. Gemini generates a routine based on inputs
3. Result page: beautiful routine card with "Compartir en Instagram/WhatsApp" button
4. Watermark: "Generado por FuturaFitness — la IA de tu entrenamiento"
5. CTA: "Guardá tu rutina → Registrate gratis"  
**Cost:** ~12 hours to build  
**Expected impact:** 2,000-5,000 monthly visitors from social sharing. 10-15% registration rate = 200-750 new users/month.

### Hack #2: "Desafío 30 Días" — Community Challenge
**What:** Launch a monthly "30-Day Challenge" program inside FuturaFitness. Example: "Desafío Abdominales 30 Días" or "30 Días de Sentadillas." Anyone can join for free. Daily workouts tracked in-app, leaderboard, and participants share progress on social.  
**Why:** Fitness challenges are the #1 viral content type in the fitness industry. Creating a structured challenge inside FuturaFitness gives people a reason to download AND keep using the app daily for 30 days. That's a month of habit-building.  
**Execution:**
1. Create challenge framework in-app (daily routine, tracking, leaderboard)
2. Launch first challenge with Instagram campaign: "¿Te animás al Desafío 30 Días?"
3. Daily Instagram Stories: highlight top participants
4. After 30 days: celebrate completions, share transformations
5. Next month: new challenge  
**Cost:** ~20 hours to build challenge feature  
**Expected impact:** 500-1,000 challenge participants per month. 30% retention rate after challenge. Each participant shares 2-3 times on social = 1,000-3,000 organic impressions.

### Hack #3: "Partner Trainer" — Reverse B2B2C
**What:** Recruit 50 personal trainers and give them FuturaFitness for FREE for 1 year. In exchange, they must: (1) onboard all their clients onto FuturaFitness, (2) post 1x/week about FuturaFitness on their Instagram, (3) share a monthly testimonial. Each trainer with 15-30 clients = instant user base.  
**Why:** Each personal trainer is a micro-influencer in their own right (they have loyal, engaged followers). If 50 trainers each onboard 20 clients, that's 1,000 active users who are being TOLD to use the app by someone they trust (their trainer). The trainers create authentic, ongoing content because they genuinely use the product.  
**Execution:**
1. Create "Partner Trainer" application page
2. Instagram outreach to personal trainers with 1k-20k followers
3. Requirements: active with clients, posts about fitness regularly, min 10 clients
4. Benefits: free Pro for 1 year, early access to features, "Verified Partner" badge
5. Monthly check-in: review posts, engagement, client count  
**Cost:** $0 (product cost only — they get free accounts instead of cash)  
**Expected impact:** 50 trainers × 20 clients = 1,000 active users. 50 trainers × 4 posts/month = 200 organic content pieces. 25% of clients become direct Pro subscribers after year 1.

---

## 📊 Marketing KPIs Dashboard

| Metric | Month 1 | Month 3 | Month 6 |
|--------|---------|---------|---------|
| Registered users (total) | 200 | 1,000 | 5,000 |
| Active trainers (coaches) | 20 | 80 | 300 |
| Active clients (students) | 100 | 500 | 2,500 |
| Paid subscribers | 10 | 50 | 200 |
| MRR (ARS) | $49,900 | $249,500 | $998,000 |
| MRR (USD) | ~$42 | ~$208 | ~$832 |
| Instagram followers | 500 | 3,000 | 10,000 |
| TikTok followers | 300 | 2,000 | 8,000 |
| Website traffic (monthly) | 2,000 | 10,000 | 40,000 |
| CAC | $5 USD | $3 USD | $2 USD |
| Free → Paid conversion | 5% | 7% | 8% |
| Monthly churn | 12% | 8% | 6% |
| AI routines generated/month | 500 | 3,000 | 15,000 |

---

## ⚠️ Pre-Launch Blockers

Before ANY marketing spend, these MUST be fixed (from review):

| Fix | Severity | Effort | Status |
|-----|----------|--------|--------|
| Rotate exposed credentials | 🔴 Critical | 1 hour | Blocks everything |
| Fix admin privilege escalation | 🔴 Critical | 2 hours | Security blocker |
| Implement payment webhooks | 🔴 High | 8 hours | Can't monetize without it |
| Server-side auth for payments | 🟡 High | 4 hours | Security requirement |
| Add Vitest + basic tests | 🟡 Medium | 6 hours | Quality gate |

**Total pre-launch fix effort: ~21 hours (~3 working days)**

---

*Plan created: 2026-02-06 | Based on MARKETING_PLAYBOOK.md + futurafitness-review.md*
