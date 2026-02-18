name: deploy-check
steps:
  - id: health
    command: "curl -sf http://192.168.100.186:4001/up"
  - id: migrations
    command: "cd ~/clawdeck && bundle exec rails db:migrate:status | grep down | wc -l"
  - id: approve
    command: "echo 'Deploy looks good. Proceed?'"
    approval: required
