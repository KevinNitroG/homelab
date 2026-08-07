# Ansible Homelab Configuration

Ansible playbooks and roles for managing homelab infrastructure.

## Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/
│   ├── hosts.yml            # Inventory definitions
│   └── group_vars/
│       ├── all.yml          # Global variables
│       └── arch_workstation.yml  # Arch workstation variables
├── playbooks/
│   ├── site.yml             # Main playbook (K3s cluster)
│   ├── arch.yml             # Arch Linux workstation setup
│   ├── k3s.yml              # K3s deployment
│   └── flux.yml             # Flux bootstrap
├── roles/
│   ├── base/                # System basics (timezone, SSH, sudo)
│   ├── packages/            # Package installation (pacman + yay)
│   ├── yay/                 # AUR helper setup
│   ├── chaotic_aur/         # Chaotic AUR repository
│   ├── shell/               # ZSH + Oh My Zsh + plugins
│   ├── tmux/                # Tmux configuration
│   ├── neovim/              # Neovim config (uitdots/nvim)
│   ├── devtools/            # npm/uv/mise packages
│   ├── openclaw/            # AI agent setup
│   └── flux/                # Flux GitOps
├── secrets/                 # Encrypted secrets (SOPS)
├── .vault_password          # Vault password (gitignored)
└── requirements.yml         # Collection dependencies
```

## Prerequisites

Install Ansible and required collections:

```bash
cd ansible/
pip install ansible
ansible-galaxy collection install -r requirements.yml
```

## Usage

### Arch Linux Workstation Setup

```bash
# Full setup
ansible-playbook playbooks/arch.yml -i inventory/hosts.yml

# Run specific tags
ansible-playbook playbooks/arch.yml -i inventory/hosts.yml --tags "packages,shell"
ansible-playbook playbooks/arch.yml -i inventory/hosts.yml --tags "yay,chaotic_aur"
ansible-playbook playbooks/arch.yml -i inventory/hosts.yml --tags "tmux,neovim"
```

### K3s Cluster

```bash
ansible-playbook playbooks/site.yml -i inventory/hosts.yml
```

## Roles

| Role | Purpose | Tags |
|------|---------|------|
| `base` | Timezone, SSH, sudo config | `base`, `system` |
| `yay` | AUR helper installation | `yay`, `aur` |
| `chaotic_aur` | Chaotic AUR repo setup | `chaotic_aur`, `repo` |
| `packages` | System packages via pacman/yay | `packages`, `apps` |
| `shell` | ZSH + Oh My Zsh + plugins | `shell`, `zsh` |
| `tmux` | Tmux with essential config | `tmux` |
| `neovim` | Neovim (uitdots/nvim) | `neovim`, `editor` |
| `devtools` | npm/uv/mise global packages | `devtools`, `npm`, `python` |
| `openclaw` | AI agent plugins/config | `openclaw`, `ai` |

## Variables

### Customizing Packages

Edit `inventory/group_vars/arch_workstation.yml`:

```yaml
packages_pacman_list:
  - git
  - curl
  - neovim
  # Add more...

packages_yay_list:
  - catppuccin-cursors-mocha
  # Add more...

devtools_npm_packages:
  - typescript
  # Add more...

devtools_uv_packages:
  - ruff
  # Add more...

devtools_mise_packages:
  - node@20
  # Add more...
```

### OpenClaw AI Agent

Enable in `inventory/group_vars/arch_workstation.yml`:

```yaml
openclaw_enabled: true
openclaw_plugins:
  - plugin-name-1
  - plugin-name-2
```

## Secrets Management

This setup uses Ansible Vault for sensitive data:

```bash
# Create encrypted file
ansible-vault create secrets/secrets.yml

# Edit encrypted file
ansible-vault edit secrets/secrets.yml

# Run playbook with vault
ansible-playbook playbooks/arch.yml --ask-vault-pass

# Or use vault password file (configured in ansible.cfg)
ansible-playbook playbooks/arch.yml
```

## SSH Access

The playbooks expect SSH access to target hosts. Update `inventory/hosts.yml`:

```yaml
arch_workstation:
  hosts:
    archbox:
      ansible_host: 192.168.28.100
      ansible_user: root
```

## License

MIT
