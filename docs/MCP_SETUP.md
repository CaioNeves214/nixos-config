# Configuração do MCP Server para Ricing NixOS

## O que foi criado

Um servidor MCP customizado que permite manipular configurações do Hyprland, Kitty, Waybar e Hyprpaper através do Claude Code.

## Instalação e Configuração

### 1. Verificar que o servidor funciona

```bash
# Na pasta do projeto
python3 test_mcp_server.py
```

Você deve ver:
```
All tests passed! ✓
```

### 2. Configurar no Claude Code

Edite o arquivo de configuração do Claude Code. Há duas opções:

**Opção A: Configuração local do projeto** (recomendado)

Edite ou crie `/home/caio/nix-config/.claude/settings.json`:

```json
{
  "mcpServers": {
    "nix-ricing": {
      "command": "python3",
      "args": [
        "-m",
        "mcp_server"
      ],
      "env": {
        "PYTHONPATH": "/home/caio/nix-config"
      }
    }
  }
}
```

**Opção B: Configuração global do usuário** (afeta todos os projetos)

Edite `~/.claude/settings.json` e adicione:

```json
{
  "mcpServers": {
    "nix-ricing": {
      "command": "python3",
      "args": [
        "-m",
        "mcp_server"
      ],
      "env": {
        "PYTHONPATH": "/home/caio/nix-config"
      }
    }
  }
}
```

### 3. Reiniciar Claude Code

Feche e reabra o Claude Code para que ele carregue o novo servidor MCP.

## Uso

Após configurar, você pode usar os tools diretamente nos prompts:

### Exemplos de uso

**Ler a configuração do Hyprland:**
```
Leia a configuração atual do Hyprland
```

**Modificar variáveis:**
```
Defina a variável $terminal para alacritty no Hyprland
```

**Configurar keybinds:**
```
Configure um keybind SUPER+Return para abrir o terminal
```

**Modificar seções:**
```
Na seção general do Hyprland, defina gaps_in = 5 e gaps_out = 10
```

**Manipular Waybar:**
```
Mostre a configuração atual do Waybar
```

**Manipular Kitty:**
```
Defina o font_size para 12 no Kitty
```

**Wallpapers:**
```
Defina o wallpaper para ~/Pictures/wallpaper.png em todos os monitores
```

## Ferramentas Disponíveis

### Hyprland (7 tools)
- `hyprland_read_config` - Lê config completa
- `hyprland_get_variable` - Obtém valor de variável
- `hyprland_set_variable` - Define variável
- `hyprland_set_keybind` - Adiciona keybind
- `hyprland_get_section` - Obtém seção
- `hyprland_update_section` - Atualiza propriedades de seção
- `hyprland_backup` - Faz backup

### Waybar (4 tools)
- `waybar_read_config` - Lê config.jsonc
- `waybar_read_style` - Lê style.css
- `waybar_add_module` - Adiciona módulo
- `waybar_backup` - Faz backup

### Kitty (3 tools)
- `kitty_read_config` - Lê config
- `kitty_set_option` - Define opção
- `kitty_backup` - Faz backup

### Hyprpaper (3 tools)
- `hyprpaper_read_config` - Lê config
- `hyprpaper_set_wallpaper` - Define wallpaper
- `hyprpaper_backup` - Faz backup

## Estrutura do Projeto

```
mcp_server/
├── __init__.py
├── __main__.py              # Entry point (python3 -m mcp_server)
├── server.py                # Servidor MCP principal
├── requirements.txt         # Dependências (nenhuma!)
├── tools/
│   ├── __init__.py
│   ├── base.py             # Classe base para tools
│   ├── hyprland.py         # Tools para Hyprland
│   ├── kitty.py            # Tools para Kitty
│   ├── waybar.py           # Tools para Waybar
│   └── hyprpaper.py        # Tools para Hyprpaper
├── README.md               # Documentação técnica
└── test_mcp_server.py      # Script de teste

dotfiles/
├── hypr/hyprland.conf      # ← Manipulado pelo servidor
├── waybar/
│   ├── config.jsonc        # ← Manipulado pelo servidor
│   └── style.css           # ← Manipulado pelo servidor
```

## Próximos Passos (Opcional)

Para expandir o servidor, você pode adicionar novos tools:

1. Crie `mcp_server/tools/novo_componente.py`
2. Herde de `BaseTool`
3. Implemente `get_tools()`
4. Registre em `server.py` no método `_register_tools()`

Exemplos de componentes futuros:
- **SDDM** - Gerenciar tema de login
- **Grub** - Configurar bootloader
- **Dunst** - Notificações
- **Rofi** - Menu de aplicações
- **zsh** - Shell configuration
- **Nvim** - Neovim configuration

## Logs e Debugging

O servidor escreve logs no stderr. Para ver mais informações ao rodar manualmente:

```bash
python3 -m mcp_server 2>&1 | tee server.log
```

Depois envie dados JSON no stdin:

```json
{"type": "initialize"}
{"type": "tools/list"}
```

## Troubleshooting

**"Module not found: mcp_server"**
- Certifique-se que o PYTHONPATH está correto na configuração do MCP

**"hyprland.conf not found"**
- O servidor procura em `~/.config/hypr/hyprland.conf`
- Se usar dotfiles, certifique-se de ter aplicado com `home-manager switch`

**Servidor não aparece no Claude Code**
- Reinicie o Claude Code
- Verifique se o arquivo de configuração está no local correto
- Verifique o log: `Ctrl+Shift+P` → "Show logs"

## Performance

- O servidor é stateless (não mantém estado entre requisições)
- Cada requisição lê o arquivo do disco (simples e seguro)
- Não há dependências externas (Python stdlib only)
- Backups são criados automaticamente com suffix `.bak`
