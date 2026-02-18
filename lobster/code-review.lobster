name: code-review
args:
  task_id:
    required: true
  repo_path:
    default: "~/clawdeck"
steps:
  - id: analyze
    command: "git -C $repo_path log --oneline -10"
  - id: review
    command: "openclaw.invoke --tool exec --args-json '{\"command\": \"cd $repo_path && git diff HEAD~1\"}'"
  - id: approve
    command: "echo 'Review complete. Approve to mark task done?'"
    approval: required
  - id: complete
    command: "curl -sf -X PATCH http://localhost:4001/api/v1/tasks/$task_id -H 'Authorization: Bearer $CLAWTROL_API_TOKEN' -H 'Content-Type: application/json' -d '{\"status\": \"done\"}'"
    condition: "$approve.exitCode == 0"
