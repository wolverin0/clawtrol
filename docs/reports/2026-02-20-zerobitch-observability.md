# ZeroBitch Observability/Editability Report (2026-02-20)

## Summary
- Added docker status/uptime/restart count, RAM percent/limit parsing, cron visibility, and last-activity formatting for ZeroBitch agents.
- Implemented inline prompt template editing with PATCH persistence and per-card logs modal.
- Prefilled dispatch prompts from agent templates in the agent detail view.

## Files Changed
- app/controllers/zerobitch_controller.rb
- app/services/zerobitch/docker_service.rb
- config/routes.rb
- app/views/zerobitch/_agent_card.html.erb
- app/views/zerobitch/index.html.erb
- app/views/zerobitch/show_agent.html.erb
- app/javascript/controllers/zerobitch_fleet_controller.js
- app/javascript/controllers/zerobitch_agent_controller.js

## Verification
- `bin/rails runner 'puts :ok'`
  - Output: `ok`
- `bin/rails routes | grep zerobitch`
  - Output:
```
                                zerobitch GET    /zerobitch(.:format)                                                                              zerobitch#index
                        zerobitch_metrics GET    /zerobitch/metrics(.:format)                                                                      zerobitch#metrics
                          zerobitch_batch POST   /zerobitch/batch(.:format)                                                                        zerobitch#batch_action
                      new_zerobitch_agent GET    /zerobitch/agents/new(.:format)                                                                   zerobitch#new_agent
                         zerobitch_agents POST   /zerobitch/agents(.:format)                                                                       zerobitch#create_agent
                          zerobitch_agent GET    /zerobitch/agents/:id(.:format)                                                                   zerobitch#show_agent
                                          DELETE /zerobitch/agents/:id(.:format)                                                                   zerobitch#destroy_agent
                    start_zerobitch_agent POST   /zerobitch/agents/:id/start(.:format)                                                             zerobitch#start_agent
                     stop_zerobitch_agent POST   /zerobitch/agents/:id/stop(.:format)                                                              zerobitch#stop_agent
                  restart_zerobitch_agent POST   /zerobitch/agents/:id/restart(.:format)                                                           zerobitch#restart_agent
                     zerobitch_agent_task POST   /zerobitch/agents/:id/task(.:format)                                                              zerobitch#send_task
                     zerobitch_agent_logs GET    /zerobitch/agents/:id/logs(.:format)                                                              zerobitch#logs
                    zerobitch_agent_tasks GET    /zerobitch/agents/:id/tasks(.:format)                                                             zerobitch#task_history
              clear_zerobitch_agent_tasks DELETE /zerobitch/agents/:id/tasks(.:format)                                                             zerobitch#clear_task_history
                   zerobitch_agent_memory GET    /zerobitch/agents/:id/memory(.:format)                                                            zerobitch#memory
          transfer_zerobitch_agent_memory POST   /zerobitch/agents/:id/memory/transfer(.:format)                                                   zerobitch#transfer_memory
                    zerobitch_assign_task POST   /zerobitch/assign_task(.:format)                                                                  zerobitch#assign_task
                          zerobitch_rules GET    /zerobitch/rules(.:format)                                                                        zerobitch#rules
                       new_zerobitch_rule GET    /zerobitch/rules/new(.:format)                                                                    zerobitch#new_rule
                    create_zerobitch_rule POST   /zerobitch/rules(.:format)                                                                        zerobitch#create_rule
                 evaluate_zerobitch_rules POST   /zerobitch/rules/evaluate(.:format)                                                               zerobitch#evaluate_rules
                    toggle_zerobitch_rule POST   /zerobitch/rules/:rule_id/toggle(.:format)                                                        zerobitch#toggle_rule
                   destroy_zerobitch_rule DELETE /zerobitch/rules/:rule_id(.:format)                                                               zerobitch#destroy_rule
                     zerobitch_agent_soul PATCH  /zerobitch/agents/:id/soul(.:format)                                                              zerobitch#save_soul
              zerobitch_agent_agents_file PATCH  /zerobitch/agents/:id/agents_file(.:format)                                                       zerobitch#save_agents
                 zerobitch_agent_template PATCH  /zerobitch/agents/:id/template(.:format)                                                          zerobitch#save_template
```
