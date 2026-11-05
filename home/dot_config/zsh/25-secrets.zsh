# Secrets loader
# The secrets live in 25-secrets.local.zsh, which chezmoi decrypts from the
# age-encrypted source file on machines that hold the age identity.
#
# Example 25-secrets.local.zsh:
#   export OPENAI_API_KEY="sk-..."
#   export ANTHROPIC_API_KEY="sk-ant-..."
#   export GITHUB_TOKEN="ghp_..."

[[ -r "${0:h}/25-secrets.local.zsh" ]] && source "${0:h}/25-secrets.local.zsh"
