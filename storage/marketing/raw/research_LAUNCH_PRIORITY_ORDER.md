# 🚀 Launch Priority Order — Combined Marketing Summary

**Created:** 2026-02-06  
**Portfolio:** 4 launch-ready projects  
**Based on:** MARKETING_PLAYBOOK.md + individual project reviews

---

## Priority Ranking

| Rank | Project | Score | Launch Readiness | Est. Pre-Launch Fixes | Recommended Launch Window |
|------|---------|-------|------------------|-----------------------|---------------------------|
| **#1** | **FuturaDelivery** | 8.0/10 | 🟢 CLOSEST | ~4 hours (credentials + storage key + social proof) | **Week of Feb 24** |
| **#2** | **FuturaCRM** | 7.5/10 | 🟡 READY with fixes | ~12 hours (service role key + OrderDetailPage + tests) | **Week of Mar 10** |
| **#3** | **NewsPage (SportStation)** | 7.0/10 | 🟡 NEEDS SECURITY PASS | ~20 hours (credential rotation + RBAC + SSR) | **Week of Mar 31** |
| **#4** | **FuturaFitness** | 6.0/10 | 🟠 NEEDS WORK | ~21 hours (credentials + auth + payment webhooks) | **Week of Apr 21** |

---

## Combined Budget Summary

### Monthly Ad Spend (All 4 Projects)

| Project | Monthly Ad Budget | Primary Channel |
|---------|-------------------|-----------------|
| FuturaDelivery | $430 USD | Instagram/Facebook (restaurant owners) |
| FuturaCRM | $720 USD | LinkedIn + Google Ads (B2B) |
| NewsPage | $800 USD | Global social (sports fans) |
| FuturaFitness | $360 USD | Instagram/TikTok (fitness community) |
| **Total** | **$2,310 USD/month** | ~**$2,772,000 ARS/month** |

### Phased Budget Approach (Recommended)
Rather than launching all 4 simultaneously, stagger:

| Phase | Months | Focus | Budget |
|-------|--------|-------|--------|
| Phase 1 | Feb-Mar | FuturaDelivery only | $430/month |
| Phase 2 | Mar-Apr | FuturaDelivery + FuturaCRM | $1,150/month |
| Phase 3 | Apr-May | + NewsPage | $1,950/month |
| Phase 4 | May-Jun | All 4 projects | $2,310/month |

---

## Free Tool Stack (All Projects)

| Tool | Purpose | Free Tier | Covers |
|------|---------|-----------|--------|
| PostHog | Analytics + Session Replay | 1M events/month | All 4 projects |
| Sentry | Error tracking | 5K errors/month | All 4 projects |
| UptimeRobot | Uptime monitoring | 50 monitors | All 4 projects |
| Brevo | Marketing email | 300/day, unlimited contacts | All 4 projects |
| Resend | Transactional email | 3,000/month | All 4 projects |
| Buffer | Social scheduling | 3 channels, 10 posts | Top 3 projects |
| Google Search Console | SEO monitoring | Unlimited | All 4 projects |

**Total infrastructure cost: $0/month** (all free tiers)

---

## Cross-Project Synergies

### 1. Shared MercadoPago Expertise
All 4 projects integrate MercadoPago. Knowledge from the first implementation (FuturaDelivery) directly benefits the other 3. Consider creating a shared MercadoPago integration library.

### 2. Shared Launch Infrastructure
One Product Hunt maker profile, one Google Ads account, one Meta Business Manager, one PostHog org — reduces overhead across all projects.

### 3. "Build in Public" Meta-Narrative
The story of launching 4+ SaaS products from Argentina is compelling on its own. Use the portfolio angle for Indie Hackers, LinkedIn, and Twitter content: "How I'm launching 4 SaaS products simultaneously from a small city in Argentina."

### 4. Cross-Promotion Opportunities
- FuturaDelivery restaurants → mention FuturaFitness for employee wellness
- FuturaCRM businesses → offer FuturaDelivery if they're in food service
- NewsPage → advertise Argentine SaaS products to local audience
- FuturaFitness → mention FuturaCRM for trainers managing business finances

---

## Revenue Projections (6-Month Outlook)

| Project | M1 MRR | M3 MRR | M6 MRR | Model |
|---------|--------|--------|--------|-------|
| FuturaDelivery | $42 | $250 | $833 | B2B subscription (ARS) |
| FuturaCRM | $62 | $312 | $999 | B2B subscription (ARS) |
| NewsPage | $80 | $800 | $4,000 | B2C premium (dual USD/ARS) |
| FuturaFitness | $42 | $208 | $832 | B2C subscription (ARS) |
| **Total** | **$226** | **$1,570** | **$6,664** | |

### Break-Even Analysis
| Project | Monthly Ad Spend | Break-Even Subscribers | Est. Time to Break-Even |
|---------|------------------|-----------------------|------------------------|
| FuturaDelivery | $430 | 54 restaurants at Emprendedor plan | Month 4-5 |
| FuturaCRM | $720 | 48 businesses at Profesional plan | Month 4-5 |
| NewsPage | $800 | 200 premium subscribers (global) | Month 3-4 |
| FuturaFitness | $360 | 90 trainers at Profesional plan | Month 5-6 |

---

## Critical Pre-Launch Checklist (All Projects)

### Security (BLOCKERS)
- [ ] **FuturaDelivery:** Rotate credentials per CREDENTIAL_ROTATION_GUIDE.md
- [ ] **FuturaCRM:** Remove VITE_SUPABASE_SERVICE_ROLE_KEY from client env
- [ ] **NewsPage:** Rotate all exposed API keys, secure Redis, fix admin RBAC
- [ ] **FuturaFitness:** Rotate credentials, fix admin privilege escalation, add payment auth

### Analytics (Required Before Ads)
- [ ] Install PostHog on all 4 projects
- [ ] Install Sentry on FuturaDelivery and FuturaCRM (payment-processing)
- [ ] Configure UptimeRobot monitors for all 4 URLs
- [ ] Set up Google Search Console for all 4 domains

### Social Media (Required Before Launch)
- [ ] Unified Instagram presence @futurasistemas.com.ar for all products
- [ ] Secure @futuradelivery on Twitter, TikTok, Facebook
- [ ] Secure @futuracrm on Twitter, LinkedIn, Facebook
- [ ] Secure @sportstation on Instagram, Twitter, TikTok, Facebook
- [ ] Secure @futurafitness on Twitter, TikTok

### Payment Processing (Required for Revenue)
- [ ] **FuturaDelivery:** MercadoPago integration verified ✅ (already working)
- [ ] **FuturaCRM:** MercadoPago integration verified ✅ (already working)
- [ ] **NewsPage:** Stripe + MercadoPago dual setup (needs verification)
- [ ] **FuturaFitness:** MercadoPago webhook implementation (MISSING — must build)

---

## Product Hunt Launch Schedule

Space launches 3 weeks apart to build momentum and learn:

| Date | Project | Day | Expected Upvotes |
|------|---------|-----|-----------------|
| **Mar 3, 2026** | FuturaDelivery | Tuesday | 200+ |
| **Mar 25, 2026** | FuturaCRM | Wednesday | 150+ |
| **Apr 14, 2026** | NewsPage (SportStation) | Tuesday | 250+ |
| **May 5, 2026** | FuturaFitness | Tuesday | 200+ |

---

## Key Risk Factors

| Risk | Projects Affected | Mitigation |
|------|-------------------|------------|
| ARS devaluation | FuturaDelivery, FuturaCRM, FuturaFitness | Offer USD pricing tier, quarterly ARS price review |
| Low trial conversion | All | Optimize onboarding, add personal follow-up for every sign-up |
| Credential exploitation | All (exposed keys) | **Fix BEFORE any marketing activity** |
| Ad budget constraints | All | Start with FuturaDelivery only, reinvest revenue |
| Solo founder bandwidth | All | Focus on 1 project at a time, use AI tools for content generation |

---

## 30-Day Action Plan (Starting Now)

### Week 1 (Feb 6-12): Fix & Prepare
- Fix security issues on FuturaDelivery (4 hours)
- Set up PostHog + Sentry on FuturaDelivery
- Secure social media handles for all 4 projects
- Create Google Ads + Meta Business accounts

### Week 2 (Feb 13-19): Content & Beta
- Record FuturaDelivery demo videos
- Design Instagram content (10 posts)
- Recruit 5 beta restaurants in Pergamino
- Create Product Hunt "Coming Soon" for FuturaDelivery

### Week 3 (Feb 20-26): Soft Launch
- Onboard beta restaurants
- Start Instagram posting for FuturaDelivery
- Start LinkedIn posting (personal profile)
- Fix FuturaCRM security issues

### Week 4 (Feb 27-Mar 5): Product Hunt Launch #1
- Launch FuturaDelivery on Product Hunt (Tuesday Mar 3)
- Full launch day protocol
- Start paid ads for FuturaDelivery
- Begin FuturaCRM beta recruitment

---

## Individual Plan Files

| Project | Marketing Plan | Size |
|---------|---------------|------|
| FuturaDelivery | [`futuradelivery-marketing.md`](./futuradelivery-marketing.md) | Complete |
| FuturaCRM | [`futuracrm-marketing.md`](./futuracrm-marketing.md) | Complete |
| NewsPage (SportStation) | [`newspage-marketing.md`](./newspage-marketing.md) | Complete |
| FuturaFitness | [`futurafitness-marketing.md`](./futurafitness-marketing.md) | Complete |

---

*Summary created: 2026-02-06 01:37 GMT-3*  
*Total marketing plans: 4 projects | ~73,000 words across all documents*
