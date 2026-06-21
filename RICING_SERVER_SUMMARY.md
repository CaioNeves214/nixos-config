# 🎨 Servidor MCP para Ricing NixOS + Hyprland

## ✨ O que foi criado

Um servidor **Model Context Protocol (MCP)** customizado que integra com Claude Code para ajudar com ricing (customização estética) do seu ambiente Linux com Hyprland.

```
┌─ Server MCP ─────────────────────┐
│  nix-ricing v0.1.0              │
│                                  │
│  17 Tools disponíveis:           │
│  • 7 Hyprland tools             │
│  • 3 Kitty tools                │
│  • 4 Waybar tools               │
│  • 3 Hyprpaper tools            │
└──────────────────────────────────┘
         ↕
   Claude Code
   (usa tools automaticamente)
         ↕
  Arquivos de config
  (hyprland.conf, kitty.conf, etc)
```

## 🚀 Instalação Rápida

### 1️⃣ Verificar que funciona
```bash
cd /home/caio/nix-config
python3 test_mcp_server.py
```

Esperado:
```
All tests passed! ✓
```

### 2️⃣ Configurar no Claude Code

**Opção A: Local do projeto** (recomendado)

Copie o arquivo de exemplo:
```bash
cp .claude/settings.example.json .claude/settings.json
```

**Opção B: Global do usuário**

Edite `~/.claude/settings.json` e adicione:
```json
{
  "mcpServers": {
    "nix-ricing": {
      "command": "python3",
      "args": ["-m", "mcp_server"],
      "env": {"PYTHONPATH": "/home/caio/nix-config"}
    }
  }
}
```

### 3️⃣ Reiniciar Claude Code
- Feche completamente o Claude Code
- Reabra

## 📋 Arquivos Criados

```
mcp_server/
├── server.py                   # Servidor MCP principal (444 linhas)
├── __main__.py                 # Entry point
├── tools/
│   ├── base.py                # Classe base (utilitários comuns)
│   ├── hyprland.py            # 7 tools para Hyprland
│   ├── kitty.py               # 3 tools para Kitty
│   ├── waybar.py              # 4 tools para Waybar
│   └── hyprpaper.py           # 3 tools para Hyprpaper
├── requirements.txt           # Nenhuma dependência externa!
├── README.md                  # Documentação técnica
└── example_test.py            # Teste interativo

.claude/
├── settings.example.json      # Exemplo de configuração
└── mcp.json                   # Config alternativa

Arquivos de documentação:
├── MCP_SETUP.md              # Guia de instalação completo
├── RICING_SERVER_SUMMARY.md  # Este arquivo
└── test_mcp_server.py        # Script de teste
```

## 🛠️ Ferramentas Disponíveis

### Hyprland (7 tools)
```python
hyprland_read_config()              # Lê config completa
hyprland_get_variable(var_name)     # Obtém $terminal, $menu, etc
hyprland_set_variable(var, value)   # Define variáveis
hyprland_set_keybind(...)           # Adiciona keybinds
hyprland_get_section(section)       # Obtém seção (general, input, etc)
hyprland_update_section(...)        # Atualiza propriedades da seção
hyprland_backup()                   # Faz backup do config
```

### Kitty (3 tools)
```python
kitty_read_config()                 # Lê config
kitty_set_option(option, value)     # Define font_size, cores, etc
kitty_backup()                      # Backup
```

### Waybar (4 tools)
```python
waybar_read_config()                # Lê config.jsonc
waybar_read_style()                 # Lê style.css
waybar_add_module(name, position)   # Adiciona módulo
waybar_backup()                     # Backup
```

### Hyprpaper (3 tools)
```python
hyprpaper_read_config()             # Lê config
hyprpaper_set_wallpaper(monitor, path)  # Define wallpaper
hyprpaper_backup()                  # Backup
```

## 💬 Exemplos de Uso no Claude Code

Depois de configurar, você pode falar naturalmente:

### Hyprland
```
"Leia a configuração do Hyprland"
"Defina $terminal para alacritty"
"Configure um keybind SUPER+Return para abrir o terminal"
"Na seção general, defina gaps_in=5 e gaps_out=10"
"Mostre a seção gestures do Hyprland"
```

### Kitty
```
"Defina o font_size para 12 no Kitty"
"Configure cores no Kitty"
```

### Waybar
```
"Mostre a configuração do Waybar"
"Leia o CSS do Waybar"
```

### Wallpapers
```
"Defina o wallpaper para ~/Pictures/wallpaper.png"
```

## 📊 Características

✅ **Sem dependências externas** — apenas Python stdlib
✅ **Modular** — fácil adicionar novos tools
✅ **Seguro** — faz backups automáticos
✅ **Stateless** — simples e previsível
✅ **Rápido** — leitura/escrita direto em arquivos
✅ **Testado** — scripts de teste inclusos

## 🔧 Como Expandir (Adicionar novos tools)

1. Crie novo arquivo `mcp_server/tools/novo_componente.py`:

```python
from .base import BaseTool
from pathlib import Path

class NovoComponenteTools(BaseTool):
    def __init__(self):
        self.config_path = Path("/caminho/para/config")
    
    def get_tools(self):
        return {
            "novo_read_config": {
                "description": "Descrição",
                "schema": {"type": "object", "properties": {}},
                "function": self.read_config_tool,
            },
        }
    
    def read_config_tool(self):
        return self.read_config()
```

2. Registre em `server.py`:

```python
def _register_tools(self):
    # ... tools existentes ...
    novo = NovoComponenteTools()
    self.tools.update(novo.get_tools())
```

Exemplos de futuros tools:
- **SDDM** — tema de login
- **Grub** — bootloader
- **Dunst** — notificações
- **Rofi** — menu
- **Zsh** — shell
- **Nvim** — editor
- **Alacritty** — terminal

## ⚙️ Arquitetura

```
┌─────────────────────────────────────┐
│   Claude Code (Interface)           │
└──────────────┬──────────────────────┘
               │ JSON-RPC stdin/stdout
┌──────────────▼──────────────────────┐
│   MCP Server (Python)               │
│   ├─ Message Handler               │
│   ├─ Tools Registry                │
│   └─ Tool Execution                │
└──────────────┬──────────────────────┘
               │
┌──────────────┼──────────────────────┐
│  Tool Classes (Base + Specificos)   │
│  ├─ HyprlandTools                  │
│  ├─ KittyTools                     │
│  ├─ WaybarTools                    │
│  └─ HyperpaperTools                │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   Arquivos de Config                │
│   ~/.config/hypr/hyprland.conf      │
│   ~/.config/kitty/kitty.conf        │
│   ~/.config/waybar/config.jsonc     │
│   ~/.config/hypr/hyprpaper.conf     │
└─────────────────────────────────────┘
```

## 🧪 Testes

Rode os testes disponíveis:

```bash
# Teste básico
python3 test_mcp_server.py

# Teste interativo com exemplos
python3 mcp_server/example_test.py
```

## 📚 Documentação

- **MCP_SETUP.md** — Guia de instalação completo
- **mcp_server/README.md** — Documentação técnica
- **Código** — Bem comentado com docstrings

## 🔍 Troubleshooting

**"No module named mcp_server"**
```bash
export PYTHONPATH=/home/caio/nix-config
python3 -m mcp_server
```

**Servidor não aparece no Claude Code**
- Reinicie completamente o Claude Code
- Verifique se settings.json está na pasta certa
- Verifique logs: `Ctrl+Shift+P` → "Show logs"

**"hyprland.conf not found"**
- Verifique: `ls ~/.config/hypr/hyprland.conf`
- Ou use: `home-manager switch --flake .#macbookpro2012`

## 🎯 Próximos Passos

1. **Configure no Claude Code** (veja seção Instalação)
2. **Teste** rodando: `python3 test_mcp_server.py`
3. **Use naturalmente** no Claude Code!

## 📝 Notas

- Backups são salvos com suffix `.bak` automaticamente
- Todas as operações são read/write de arquivos (nada é executado automaticamente)
- O servidor é stateless (cada requisição é independente)
- Sem dependências externas = sem pip install necessário!

---

**Criado em:** 2026-06-21
**Status:** ✅ Testado e Funcional
**Versão:** 0.1.0
