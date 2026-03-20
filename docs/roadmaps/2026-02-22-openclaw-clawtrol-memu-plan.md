NOTE: Superseded on 2026-02-23 by docs/roadmaps/2026-02-23-clawtrol-master-roadmap.md.
This file remains for historical reference only.

# OpenClaw + ClawTrol Plan (Upgrade + Topics + Model Routing + memU)

Fecha: 2026-02-22
Owner: Codex (implementacion) + Gonzalo (decisiones de naming/routing final)
Estado: PLAN (sin aplicar)

## 1) Objetivo
Dejar el stack estable, entendible y operable para uso diario:
- Adoptar lo util de la version nueva de OpenClaw sin romper runtime.
- Renombrar/subetiquetar topics para que dejen de verse como IDs crudos.
- Alinear modelo + auth profile por topic con politica de costos/calidad.
- Integrar memU como capa opcional complementaria (no reemplazo inmediato de QMD).

## 2) Diagnostico base (hoy)
- El routing efectivo de Telegram esta saliendo de sessions.json (no de openclaw.json).
- Hay topics con subject vacio y mezcla de topics activos + legacy.
- Hay topics con authProfileOverride vacio (cae en default implicito).
- memory.backend nativo de OpenClaw es builtin o qmd; memU requiere integracion externa (hooks/sidecar).

## 3) Alcance
### Incluye
- Auditoria de release OpenClaw reciente y adopcion selectiva.
- Matriz canonica Topic -> Nombre -> Modelo -> Auth.
- Normalizacion de metadata de sesiones/topic labels.
- Integracion memU en modo canary (opt-in) con rollback.
- Tests de humo funcionales (Telegram PM, topic 1, topic 216, topic 1528, auto-pull).

### No incluye
- Reescritura del pipeline ClawTrol.
- Migracion total de memoria fuera de QMD en una sola pasada.

## 4) Workstreams

## WS-A: Upgrade y compatibilidad OpenClaw
Objetivo: asegurar que la version nueva aporte mejoras sin regresiones.

Pasos:
1. Snapshot de config/runtime actual (openclaw.json, sessions.json, auth profiles, services user).
2. Diff contra upstream release notes (ultimos 3 releases) y checklist de features relevantes:
   - cron concurrency (cron.maxConcurrentRuns)
   - mejoras de memory/QMD
   - robustez subagents
   - observabilidad de fallback/modelo
3. Validar config keys soportadas en runtime actual (evitar campos no reconocidos como channels.modelByChannel si no aplica).
4. Documentar compat matrix: Soportado, No soportado, Requiere workaround.

Criterio de exito:
- Servicios openclaw-gateway y openclaw-node levantan limpios.
- openclaw status --all sin errores de parse/config.

## WS-B: Renombre de canales/topics
Objetivo: visibilidad humana en vez de IDs crudos.

Pasos:
1. Inventario final de topics activos del grupo principal (-1003748927245) y legacy.
2. Definir nomenclatura canonica (ejemplo):
   - 1 general
   - 216 brainstorm
   - 1528 wispbot
   - 24 research
   - 25 dev
   - 200 dieta
3. Aplicar labels en la fuente que realmente usa runtime (hoy: sesiones).
4. Marcar topics legacy como archived/* o excluirlos del routing activo.

Criterio de exito:
- En logs/reportes internos aparece nombre consistente por topic.
- Cero ambiguedad sobre que topic es cual.

## WS-C: Alineacion modelo + auth por topic
Objetivo: routing predecible, costo controlado y fallback explicito.

Politica objetivo (base, ajustable):
- general/dev/coding: gpt-5.3-codex + openai-codex:default
- brainstorm/research bulk: gemini-3-flash-preview + google-gemini-cli:oauth
- planificacion critica: claude-opus-4-6 + anthropic:mariano (si key OK)

Pasos:
1. Tabla unica por topic: topic_id, name, primary_model, primary_auth, fallback_1, fallback_2, no_forward_fallback.
2. Completar authProfileOverride faltantes para eliminar defaults implicitos.
3. Validar que cada provider tenga auth real (sin 401/cooldown).
4. Pruebas dirigidas: mensaje de prueba por topic + verificacion en log de provider/model real.

Criterio de exito:
- Cada topic responde con el modelo esperado (evidencia en openclaw.log).
- Sin sorpresas de modelo por defaults ocultos.

## WS-D: Integracion memU (complementaria a QMD)
Objetivo: agregar memoria episodica sin romper flujo actual.

Estrategia recomendada:
- Mantener QMD como backend de memory_search (estable y nativo).
- Integrar memU como sidecar opcional para write/read de memoria operativa.

Fases:
1. Canary local:
   - levantar memU service local
   - endpoint health + memorize + retrieve
2. Hook no intrusivo:
   - post-task outcome -> write resumido a memU
   - pre-task context -> retrieve desde memU con timeout estricto
3. Guardrails:
   - circuit breaker (si memU falla, continuar con QMD sin bloquear)
   - budgets de tokens para inyeccion de memoria
4. Medicion:
   - latencia promedio
   - tasa de hit util
   - impacto en calidad de follow-up

Criterio de exito:
- Si memU cae, OpenClaw sigue operando normal con QMD.
- Si memU responde, mejora continuidad de contexto sin inflar prompts.

## WS-E: Validacion end-to-end y operacion
Objetivo: cerrar con evidencia y playbook.

Checklist de validacion:
1. PM directo responde menor a 20s en carga normal.
2. Topic 1, 216, 1528 responden con modelo correcto.
3. Auto-pull: claim -> wake -> ejecucion -> in_review con notificacion.
4. task_outcome_reported siempre emite YES/NO follow-up.
5. Dashboard ClawTrol refleja estado sin inconsistencias pipeline stage.

Entregables:
- docs/reports/openclaw-clawtrol-upgrade-validation-YYYY-MM-DD.md
- Tabla final de routing por topic.
- Runbook corto de recuperacion (gateway lock, auth fail, rate limit, disk pressure).

## 5) Orden de ejecucion propuesto
1. WS-A (compatibilidad release)
2. WS-B (renombres)
3. WS-C (alineacion modelos/auth)
4. WS-D (memU canary)
5. WS-E (validacion + reporte final)

## 6) Riesgos y mitigaciones
- Riesgo: cambio de config key no soportada rompe gateway.
  - Mitigacion: validacion previa + rollback inmediato de archivo backup.
- Riesgo: auth de Anthropic invalida/intermitente.
  - Mitigacion: healthcheck previo, fallback policy por topic.
- Riesgo: memU agrega latencia.
  - Mitigacion: timeout bajo + async write + fallback a QMD.

## 7) Rollback plan
- Restaurar backups de:
  - ~/.openclaw/openclaw.json
  - ~/.openclaw/agents/main/sessions/sessions.json
  - overrides systemd user
- Reiniciar servicios user y verificar openclaw status --all.

## 8) Aprobaciones requeridas (tuyas)
1. Lista final de nombres por topic.
2. Matriz final de modelo/auth/fallback por topic.
3. Activar memU en canary (ON/OFF).

---

## Anexo A: Inventario activo actual (base)
Grupo activo: -1003748927245
- 1, 21, 22, 23, 24, 25, 27, 28, 48, 200, 215, 216, 1528

Legacy detectado:
- grupo -1002487515185 topic 24
- grupo -1002345678901 topic 27

## 9) Estado aplicado en runtime (2026-02-22 02:25 ART)

Aplicado ahora (en vivo):
- Session routing alineado en ~/.openclaw/agents/main/sessions/sessions.json.
- Topics creados faltantes: 19, 20, 26.
- Renombre + modelo + auth aplicado en topics activos del grupo -1003748927245.
- Restart de openclaw-gateway y openclaw-node completado (ambos active).

Backup generado:
- ~/.openclaw/agents/main/sessions/sessions.json.bak-routing-20260222-022449

Matriz aplicada:
- 1 General -> claude-sonnet-4-6 / anthropic:mariano
- 19 Agent Runs -> gemini-3-flash-preview / google-gemini-cli:oauth
- 20 Cron Updates -> gemini-3-flash-preview / google-gemini-cli:oauth
- 21 Infra Alerts -> gemini-3-flash-preview / google-gemini-cli:oauth
- 22 Self Audit -> claude-opus-4-6 / anthropic:mariano
- 23 Analytics -> gemini-3-flash-preview / google-gemini-cli:oauth
- 24 Research -> gemini-3-flash-preview / google-gemini-cli:oauth
- 25 Dev Log -> gemini-3-flash-preview / google-gemini-cli:oauth
- 26 Food Journal -> gemini-3-flash-preview / google-gemini-cli:oauth
- 27 Daily Brief -> gemini-3-flash-preview / google-gemini-cli:oauth
- 28 General -> claude-sonnet-4-6 / anthropic:mariano
- 48 Saved Links -> gemini-3-flash-preview / google-gemini-cli:oauth
- 200 Diet -> gemini-3-flash-preview / google-gemini-cli:oauth
- 215 Mission Control -> claude-opus-4-6 / anthropic:mariano
- 216 Brainstorm -> claude-opus-4-6 / anthropic:mariano
- 1528 wispBOT -> claude-opus-4-6 / anthropic:mariano

## 10) Hallazgo importante: channels.modelByChannel

Resultado validado en esta build (openclaw 2026.2.21-2):
- El changelog menciona channels.modelByChannel.
- El validador de config sigue rechazando esa key dentro de channels como unknown channel id: modelByChannel.
- Evidencia en runtime bundle: dist/config-*.js valida channels.* contra lista cerrada de channel IDs + defaults.

Conclusion operativa:
- Mantener workaround estable por session routing (sessions.json) hasta fix upstream.

## 11) Siguiente bloque (pendiente)

1. GMG: revisar tareas inbox/up_next, consolidar y cerrar flujo de dashboard de leads.
2. Codemap: continuar roadmap tecnico y evidencia de avance por commit.
3. Wiki :4010: hoy no hay servicio escuchando en ese puerto; levantar deploy persistente (systemd user) y healthcheck.

## 12) Avance aplicado (2026-02-22 02:47 ART)

Codemap (live monitor):
- Runtime-first reforzado en app/javascript/controllers/visualizer_controller.js.
- Regla aplicada: si ya hay runtime signals, no usar fallback de transcript para panel/event feed.
- UI corregida en app/views/codemap_monitor/index.html.erb (status line limpia, sin artefactos).
- Test visual actualizado al contrato actual en test/system/codemap_monitor_visual_test.rb.

Validaciones ejecutadas:
- PARALLEL_WORKERS=1 bundle exec rails test test/system/codemap_monitor_visual_test.rb -> PASS (1 runs, 12 assertions).
- PARALLEL_WORKERS=1 bundle exec rails test test/services/queue_orchestration_selector_test.rb test/services/agent_auto_runner_service_test.rb -> PASS (21 runs, 65 assertions).
- systemctl --user restart clawdeck-web.service -> active.

GMG continuidad (sin bloat de tasks):
- Task master #316 reencolada a up_next (misma task id) para follow-up.
- Se mantuvo modelo gemini3 y se agrego bloque FOLLOW-UP RUN #2 en la misma descripcion.
- Objetivo: terminar DoD de dashboard de leads sin crear nuevas cards.

Estado rapido boards:
- GMG (board 6): #316 tomada por autopull y en in_progress.
- Codemap (board 11): fases en in_review y monitor live ya validado por test.
