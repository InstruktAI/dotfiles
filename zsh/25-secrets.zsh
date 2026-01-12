# Secrets loader
# Actual secrets go in 25-secrets.local.zsh (gitignored)
#
# Example 25-secrets.local.zsh:
#   export OPENAI_API_KEY="sk-..."
#   export ANTHROPIC_API_KEY="sk-ant-..."
#   export GITHUB_TOKEN="ghp_..."

[[ -r "${0:h}/25-secrets.local.zsh" ]] && source "${0:h}/25-secrets.local.zsh"
