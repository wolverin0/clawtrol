# Futura Sistemas — Social Media Image Prompts (gpt-image-1)

## 🎯 Fórmula Base
```
[Tipo de imagen] + [Sujeto/Producto] + [Background/Setting] + [Estilo/Iluminación/Mood] + [Texto a incluir] + [Formato]
```

**Reglas clave:**
- Palabras importantes al principio (AI prioriza las primeras)
- 50-100 palabras, específico, no vago
- Siempre especificar: colores de marca, aspect ratio, tipografía
- Iterar: generar 2-3 variaciones, ajustar un elemento por vez

## 🎨 Brand Guide - Futura Sistemas
- **Colores:** Deep navy (#0a1628) → Electric cyan (#00d4ff) gradient
- **Font style:** Modern geometric sans-serif (Futura/Inter/Geist)
- **Mood:** Premium tech, clean, innovative, trustworthy
- **Elementos:** Circuit traces, glowing nodes, data flows, subtle grids
- **Evitar:** Stock photo look, generic, cluttered, clipart

---

## 📦 PRODUCTO: Delivery Management

### Post de producto
```
Professional product showcase of a delivery management SaaS dashboard on a MacBook Pro screen, showing real-time delivery routes on a map with glowing cyan tracking dots, dark navy background with subtle grid pattern, modern minimalist UI design. Text overlay: "FUTURA DELIVERY" in bold white geometric sans-serif font top-center, below: "Rutas inteligentes. Entregas perfectas." in light cyan. Soft ambient lighting, shallow depth of field on screen. 1:1 square format for Instagram.
```

### Post de feature
```
Clean infographic-style illustration showing a split-screen comparison: left side chaotic manual delivery planning in muted grays, right side organized AI-optimized routes in glowing blue and cyan. Futuristic data visualization aesthetic. Bottom banner: "FUTURA DELIVERY" with tagline "De caos a control en un click". Dark background, neon accents, 16:9 landscape for Facebook/LinkedIn.
```

### Story/Reel cover
```
Vertical 9:16 dynamic graphic of a delivery truck icon transforming into digital data streams flowing upward, deep blue to cyan gradient background with particle effects. Bold text center: "TU DELIVERY. AUTOMATIZADO." White modern font, glowing cyan underline. Tech startup energy, premium feel.
```

---

## 💪 PRODUCTO: Fitness App

### Post de producto
```
Photorealistic mockup of a fitness tracking app on iPhone 16 Pro, showing workout dashboard with progress rings in electric cyan and deep blue, heart rate graph, and macro tracker. Phone floating at slight angle against dark navy gradient background with subtle gym equipment silhouettes. Text: "FUTURA FITNESS" bold white top, "Tu entrenamiento. Tu data. Tu progreso." below in cyan. Clean, modern, Apple-quality product shot. 1:1 square.
```

### Post motivacional
```
High-contrast dramatic photo of a person mid-workout with digital overlay elements — heart rate numbers, rep counters, calorie burn stats floating around them in holographic cyan blue. Dark gym background with single dramatic rim light. Bottom text: "FUTURA FITNESS — Entrenamiento con inteligencia". Cinematic style, 4:5 portrait for Instagram.
```

---

## 📊 PRODUCTO: CRM

### Post de producto  
```
Professional product visualization of a CRM dashboard interface on a widescreen monitor, showing customer pipeline with colorful deal stages, contact cards, and revenue graphs in blues and cyans. Modern office desk setup with minimal props. Overhead soft lighting, clean white desk. Text overlay: "FUTURA CRM" bold geometric font, "Cada cliente cuenta. Cada venta importa." Premium SaaS aesthetic, 16:9 landscape.
```

### Post de testimonial/caso de éxito
```
Professional infographic with rising revenue chart breaking through a geometric frame, numbers glowing in cyan. Dark navy background with subtle data grid. Quote bubble: "[Empresa] creció 40% con Futura CRM". Company name "FUTURA CRM" bottom-right with logo mark. Gradient blue accent bar. Motivational and data-driven mood. 1:1 square.
```

---

## 🏢 MARCA: Futura Sistemas (General)

### Hero banner
```
Cinematic wide-angle shot of interconnected glowing blue circuit board traces forming a city skyline silhouette against deep navy sky transitioning to electric cyan at horizon. Small glowing nodes at intersections pulsing with light. Center text: "FUTURA SISTEMAS" in large bold white geometric sans-serif, below: "Software que impulsa tu negocio" in thin light cyan. Premium tech brand quality, Vercel/Stripe aesthetic. 16:9 landscape, 2K resolution.
```

### Post "Quiénes somos"
```
Isometric 3D illustration of a tech ecosystem: three connected platforms (delivery truck, dumbbell, handshake icon) orbiting a central glowing sphere labeled "FUTURA", connected by flowing data streams in cyan and blue. Dark navy background, subtle particle effects. Clean vector-style with soft 3D shadows. Text bottom: "Un ecosistema. Tres soluciones. Infinitas posibilidades." Modern tech illustration style. 1:1 square.
```

### Post de equipo/cultura
```
Professional lifestyle photo of a diverse tech team collaborating around holographic floating UI screens in a modern Argentine office space, warm afternoon light through large windows, Buenos Aires skyline visible. Natural and innovative energy. Subtle blue tech overlay effects. Text: "El equipo detrás de la tecnología — FUTURA SISTEMAS". 16:9 landscape.
```

---

## 🔄 Variaciones rápidas (cambiar UN elemento)

### Lighting
- `soft ambient lighting` → para producto
- `dramatic rim lighting` → para impacto
- `warm golden hour` → para cultura/equipo
- `neon glow, high contrast` → para features tech

### Mood
- `professional and trustworthy` → LinkedIn
- `energetic and innovative` → Instagram
- `data-driven and precise` → Facebook
- `bold and disruptive` → Twitter/X

### Format
- `1:1 square` → Instagram feed
- `4:5 portrait` → Instagram feed (más grande)
- `9:16 vertical` → Stories/Reels
- `16:9 landscape` → Facebook/LinkedIn/YouTube
- `1200x628px` → Facebook link preview

---

## ⚡ Quick Generate Script
```bash
# Generar + publicar en FB en un comando
python3 /home/ggorbalan/.openclaw/workspace/scripts/generate_and_post.py \
  --prompt "PROMPT_AQUÍ" \
  --caption "CAPTION_AQUÍ" \
  --page futura-sistemas
```
