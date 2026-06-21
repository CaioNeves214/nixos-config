# MCP Server para Ricing NixOS + Hyprland

Servidor MCP (Model Context Protocol) customizado para ajudar com ricing (customização estética) de Linux com Hyprland no NixOS.

## Funcionalidades

### Hyprland Tools
- `hyprland_read_config` - Lê a configuração completa
- `hyprland_get_variable` - Obtém valor de uma variável ($terminal, $menu, etc)
- `hyprland_set_variable` - Define uma variável
- `hyprland_set_keybind` - Define keybinds
- `hyprland_get_section` - Obtém uma seção (general, input, gestures, etc)
- `hyprland_update_section` - Atualiza propriedades de uma seção
- `hyprland_backup` - Faz backup da config

### Kitty Tools
- `kitty_read_config` - Lê a configuração
- `kitty_set_option` - Define opções (font_size, foreground, background, etc)
- `kitty_backup` - Faz backup

### Waybar Tools
- `waybar_read_config` - Lê a configuração
- `waybar_read_style` - Lê o arquivo CSS
- `waybar_add_module` - Adiciona módulos
- `waybar_backup` - Faz backup

### Hyprpaper Tools
- `hyprpaper_read_config` - Lê a configuração
- `hyprpaper_set_wallpaper` - Define wallpaper para monitor
- `hyprpaper_backup` - Faz backup

## Uso

### Configuração no Claude Code

1. Adicione o servidor MCP no seu `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "nix-ricing": {
      "command": "python3",
      "args": [
        "-m",
        "mcp_server.server"
      ],
      "env": {
        "PYTHONPATH": "/home/caio/nix-config"
      }
    }
  }
}
```

2. Reinicie o Claude Code

### Uso nos prompts

Use qualquer um dos tools acima. Exemplos:

```
Leia a configuração do Hyprland e mostre a seção general
```

```
Defina o $terminal para alacritty no Hyprland
```

```
Configure um keybind SUPER+D para abrir rofi no Hyprland
```

## Estrutura do Servidor

```
mcp_server/
├── server.py           # Servidor MCP principal (stdin/stdout JSON-RPC)
├── tools/
│   ├── base.py        # Classe base para tools
│   ├── hyprland.py    # Tools para Hyprland
│   ├── kitty.py       # Tools para Kitty
│   ├── waybar.py      # Tools para Waybar
│   └── hyprpaper.py   # Tools para Hyprpaper
└── requirements.txt    # Dependências (none!)
```

## Desenvolvimento

Para adicionar novos tools:

1. Crie um novo arquivo em `mcp_server/tools/` herdando de `BaseTool`
2. Implemente `get_tools()` retornando um dict com os tools
3. Registre os tools no `_register_tools()` em `server.py`

### Exemplo: Adicionar tool para SDDM

```python
# mcp_server/tools/sddm.py
from .base import BaseTool

class SDDMTools(BaseTool):
    def __init__(self):
        self.config_path = Path("/etc/sddm.conf.d/kde_settings.conf")
    
    def get_tools(self):
        return {
            "sddm_set_theme": {
                "description": "Define o tema SDDM",
                "schema": {...},
                "function": self.set_theme,
            }
        }
    
    def set_theme(self, theme_name: str) -> str:
        # implementação
```

Depois registre em `server.py`:

```python
def _register_tools(self):
    # ...
    sddm = SDDMTools()
    self.tools.update(sddm.get_tools())
```

## Limitações e TODOs

- [ ] Parser JSON/JSONC mais robusto para Waybar
- [ ] Suporte para Hyprland subconfigs (source)
- [ ] Validação de configuração após mudanças
- [ ] Recarregar configuração dinamicamente (hyprctl)
- [ ] Tools para SDDM, Grub, etc
- [ ] Testes unitários

## Logs

O servidor escreve logs no stderr. Para ver mais detalhes ao rodar manualmente:

```bash
python3 -m mcp_server.server
```

Digite JSON no stdin, ex:

```json
{"type": "initialize"}
{"type": "tools/list"}
{"type": "tools/call", "name": "hyprland_read_config", "arguments": {}}
```
