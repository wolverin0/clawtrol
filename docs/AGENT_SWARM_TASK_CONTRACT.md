# Swarm Task Contract

This document defines the structured payload attached to tasks launched from `/swarm` and `/api/v1/swarm_ideas/:id/launch`.

## Version

- Current version: `2026-02-23.v1`
- Service: `app/services/swarm_task_contract.rb`

## Purpose

Make Swarm launches deterministic for orchestration:
- explicit execution settings,
- explicit acceptance criteria,
- explicit artifact expectations,
- stable contract id for tracking.

## Contract Shape

```json
{
  "version": "2026-02-23.v1",
  "contract_id": "ab12cd34ef56...",
  "generated_at": "2026-02-23T16:21:00Z",
  "orchestrator": "swarm",
  "phase": "single_phase",
  "idea": {
    "id": 123,
    "title": "...",
    "description": "...",
    "category": "code"
  },
  "execution": {
    "board_id": 1,
    "model": "codex",
    "pipeline_type": "feature",
    "estimated_minutes": 30
  },
  "acceptance_criteria": ["..."],
  "required_artifacts": ["..."],
  "skills": ["..."]
}
```

## Persistence in Task

When a swarm idea is launched, the contract is persisted in:
- `tasks.review_config["swarm_contract"]`
- `tasks.state_data["swarm_contract"]`
- `tasks.state_data["swarm_contract_status"] = "created"`

The generated execution summary is stored in:
- `tasks.execution_plan`

## Validation Rules

`SwarmTaskContract.validate` enforces:
- `version` present
- `contract_id` present
- `idea.title` present
- `execution.board_id > 0`
- `execution.model` present
- non-empty `acceptance_criteria`
- non-empty `required_artifacts`

Invalid contracts block launch with `422`/UI alert.

## Overrides

Launch callers can override contract fields with:
- `orchestrator`
- `phase`
- `acceptance_criteria`
- `required_artifacts`
- `skills`
