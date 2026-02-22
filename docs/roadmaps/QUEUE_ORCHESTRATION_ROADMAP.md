# Queue Orchestration Roadmap (OpenClaw + ClawTrol)

Last updated: 2026-02-21
Owner: Codex + Gonzalo
Scope: Ejecutar multiples tasks de forma autonoma, ordenada y estable (sin bloat de kanban).

## Objetivo
Permitir dejar muchas tareas en `up_next` (ej: 40) para ejecucion nocturna con estas reglas:
- maximo 1 `in_progress` por board
- seleccion por menor `task_id` por board (FIFO)
- cupos por LLM/proveedor para evitar saturacion
- watchdog de bloqueos/rate-limit/stall
- follow-up en la misma task (sin crear tasks hijas)

## Politica Objetivo (acordada)
- Planning fallback chain: `opus -> codex -> gemini3`
- Coding fallback chain: `codex -> sonnet -> gemini3`
- Easy/bulk chain: `gemini3-flash -> glm`
- Nunca fall-forward a modelo mas caro fuera de la cadena definida.
- Night window: 23:00-08:00 (GMT-3 / America/Argentina/Buenos_Aires)

## Fases

### Fase 0 - Baseline y contrato
- [x] Definir politica de cola y fallback
- [x] Definir comportamiento de follow-up en misma task
- [x] Crear roadmap operativo con progreso

### Fase 1 - Scheduler de cola por board
- [x] Implementar selector `top-1 por board` en `up_next` ordenado por `id ASC`
- [x] Respetar regla `1 in_progress` max por board
- [x] Loop por rondas hasta completar `max_concurrent` global
- [x] Mantener cooldown actual de claim para evitar spam (per-task wake cooldown)

### Fase 2 - Cuotas por LLM / proveedor
- [x] Agregar `model_max_inflight` (cupo duro por modelo)
- [x] Agregar `provider_max_inflight` (cupo por proveedor)
- [x] Saltar claim cuando cupo agotado y registrar motivo (`quota_reached`)

### Fase 3 - Watchdog de estabilidad
- [x] Detectar task `in_progress` sin heartbeat > N minutos y requeue seguro
- [x] Circuit breaker por rate-limit por modelo (ModelLimit activo)
- [x] Cooldown por modelo con auto-retry posterior
- [x] Log de causa raiz (`timeout`, `rate_limit`, `pairing`, `quota_reached`)

### Fase 4 - Follow-up sin bloat
- [x] Outcome obligatorio siempre (YES/NO follow-up)
- [x] Si YES: misma task vuelve a `up_next` con contexto acumulado
- [x] Si NO: task queda en `in_review` y notifica igual
- [x] No crear task nueva para follow-up por defecto

### Fase 5 - Night mode
- [x] Ajustar `max_concurrent` nocturno (base 4 -> noche 8, configurable)
- [x] Mantener guardrails de cuota/modelo en modo nocturno
- [x] Reporte resumen periodico (Telegram) durante cola activa

### Fase 6 - Observabilidad
- [x] Metricas por board: queue depth / in_progress / throughput (queue depth + in_progress implementado)
- [x] Metricas por modelo: inflight / failures / cooldown (inflight + active limits implementado)
- [x] Vista de health del runner con ultimos errores accionables (`/api/v1/tasks/queue_health`)

### Fase 7 - Validacion E2E
- [x] Simulacion con 40 tasks en `up_next` multi-board
- [x] Verificar fairness por board + orden FIFO
- [x] Verificar cumplimiento de cupos por LLM/proveedor
- [x] Verificar follow-up same-task (sin bloat)
- [x] Verificar reportes de cierre y alertas

## Config propuesta (primera version)
```yaml
queue:
  global_max_concurrent: 6
  one_in_progress_per_board: true
  pick_order: task_id_asc

limits:
  model_max_inflight:
    opus: 2
    codex: 2
    sonnet: 2
    gemini3: 3
    gemini3_flash: 4
    glm: 4
  provider_max_inflight:
    anthropic: 3
    openai: 3
    google: 4
    zai: 4

watchdog:
  stale_in_progress_minutes: 20
  heartbeat_grace_minutes: 3
  rate_limit_cooldown_minutes: 10

night_mode:
  timezone: America/Argentina/Buenos_Aires
  start: "23:00"
  end: "08:00"
  global_max_concurrent: 8
```

## Bitacora de progreso
- 2026-02-21: roadmap creado y politica consolidada desde brainstorm.
- 2026-02-21: implementado selector de cola por board (`QueueOrchestrationSelector`) + cuotas por modelo/proveedor + night/day concurrency.
- 2026-02-21: integrado en `AgentAutoRunnerService` y en endpoint `GET /api/v1/tasks/next`.
- 2026-02-21: agregado endpoint de observabilidad `GET /api/v1/tasks/queue_health`.
- 2026-02-21: implementado `requeue_same_task` en `TaskOutcomeService` (misma task vuelve a `up_next`).
- 2026-02-21: tests target en verde (46 runs, 136 assertions, 0 failures).
- 2026-02-21: simulacion e2e de 40 tasks multi-board documentada en `docs/reports/2026-02-21-queue-orchestration-simulation.md`.
- 2026-02-21: agregado resumen periodico de cola al runner (wake + notification) con cooldown configurable (`AUTO_RUNNER_SUMMARY_INTERVAL_MINUTES`).
- 2026-02-21: validacion de alertas/reportes completada con test suite target (47 runs, 139 assertions, 0 failures).

## Riesgos y mitigacion
- Riesgo: saturacion por provider outage.
  - Mitigacion: cupos por proveedor + circuit breaker + cooldown.
- Riesgo: tasks zombis en `in_progress`.
  - Mitigacion: watchdog de heartbeat y requeue seguro.
- Riesgo: bloat del kanban por follow-up.
  - Mitigacion: requeue de la misma task con run_count/contexto.

## Criterio de cierre del roadmap
Se considera cerrado cuando la corrida nocturna de 40 tasks:
- completa sin atascar el runner
- respeta 1 por board + FIFO por id
- respeta limites por LLM/proveedor
- reporta outcome de cada task
- mantiene follow-up en misma task
