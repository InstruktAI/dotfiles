# Dotfiles

Personal dotfiles for a consistent terminal environment across macOS and Linux,
managed with chezmoi. `README.md` is the full reference; this file is what an
agent needs before changing anything.

## How it works

- The repository is a chezmoi source. `.chezmoiroot` points chezmoi at `home/`;
  the root stays free for project files (docs, CI).
- Every machine installs it with `chezmoi init --apply InstruktAI/dotfiles`
  (clone in `~/.local/share/chezmoi`) and pulls changes through a scheduled
  `chezmoi update` (launchd on macOS, a systemd `--user` timer on Linux).
- Machine differences are templates plus chezmoi data: defaults in
  `home/.chezmoidata/defaults.toml`, per-machine overrides under `[data]` in
  that machine's `~/.config/chezmoi/chezmoi.toml`. There are no `*.local.*`
  override files.
- Secrets are age-encrypted files in the source (`encrypted_*.age`); each machine
  holds the identity at `~/.config/chezmoi/key.txt`.
- Install steps are `run_once_`/`run_onchange_` scripts in `home/.chezmoiscripts/`.

## Rules for changes

- Change the source in git, never a managed file in `~`: the next apply or
  scheduled update overwrites it.
- Never commit machine-identifying values: coordinates, host names, usernames,
  keys, absolute machine paths. Those belong in machine-local chezmoi data.
- Never commit a plaintext secret. Add secrets with `chezmoi add --encrypt`.
- Scripts must be idempotent. A script that needs a person (sudo, prompts) is
  wrapped in the `unattended-guard` check so the scheduled update skips it.
- A `run_onchange_` script that must react to another file carries that file's
  hash in a comment (`include …| sha256sum` or `includeTemplate …| sha256sum`).
- Verify against a throwaway destination, never the real home: run chezmoi with
  `HOME` set to a temporary directory, `--source` pointing at this checkout,
  and `apply --exclude=scripts`; render scripts and other OSes with
  `chezmoi execute-template --override-data '{"chezmoi":{"os":"linux"}}'`.

## Where things are

- `home/dot_config/zsh/` — modular zsh configuration (see its `AGENTS.md`).
- `home/modify_dot_zshrc` — keeps the block that sources `~/.config/zsh/init.zsh`
  inside the machine's own `~/.zshrc`.
- `home/dot_local/bin/executable_appearance` and
  `home/dot_local/libexec/appearance/` — appearance management (see that
  directory's `AGENTS.md`).
- `home/dot_config/homebrew/` — Brewfiles; `dotfiles-brew` installs, diffs and
  upgrades from them.
- `home/Library/LaunchAgents/`, `home/dot_config/systemd/user/` — service
  definitions; their `run_onchange_after_50-*` scripts reload them.
- `home/.chezmoiscripts/run_onchange_after_60-beszel-agent.sh.tmpl` — Beszel
  monitoring agent, installed where `beszel.key` is set.
- `iterm2/` — iTerm2 preferences folder, read and written in the working tree.
