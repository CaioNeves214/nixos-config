"""Tools para manipular configuração do Waybar."""

from pathlib import Path
import json
from .base import BaseTool


class WaybarTools(BaseTool):
    """Tools para Waybar - gerencia config.jsonc."""

    def __init__(self):
        # Waybar usa config.jsonc (JSON com comentários)
        config_path = Path.home() / ".config/waybar/config.jsonc"
        if not config_path.exists():
            config_path = Path(__file__).parent.parent.parent / "dotfiles/waybar/config.jsonc"
        if not config_path.exists():
            raise FileNotFoundError("waybar config.jsonc not found")
        self.config_path = config_path

    def get_tools(self) -> dict:
        """Retorna os tools disponíveis para Waybar."""
        return {
            "waybar_read_config": {
                "description": "Lê a configuração do Waybar",
                "schema": {"type": "object", "properties": {}},
                "function": self.read_config_tool,
            },
            "waybar_read_style": {
                "description": "Lê o arquivo de style.css do Waybar",
                "schema": {"type": "object", "properties": {}},
                "function": self.read_style,
            },
            "waybar_add_module": {
                "description": "Adiciona um novo módulo ao Waybar",
                "schema": {
                    "type": "object",
                    "properties": {
                        "module_name": {"type": "string", "description": "Nome do módulo (ex: clock, pulseaudio)"},
                        "position": {"type": "string", "description": "Posição (left, center, right)"},
                    },
                    "required": ["module_name", "position"],
                },
                "function": self.add_module,
            },
            "waybar_backup": {
                "description": "Faz backup da configuração do Waybar",
                "schema": {"type": "object", "properties": {}},
                "function": lambda: self.backup(),
            },
            "waybar_read_section": {
                "description": "Lê uma seção específica do config ou style (ex: module 'clock', CSS selector '#waybar')",
                "schema": {
                    "type": "object",
                    "properties": {
                        "section": {"type": "string", "description": "Nome da seção (ex: clock, pulseaudio, #waybar, #window)"},
                        "file_type": {"type": "string", "enum": ["config", "style"], "description": "Tipo de arquivo"},
                    },
                    "required": ["section", "file_type"],
                },
                "function": self.read_section,
            },
        }

    def read_config_tool(self) -> str:
        """Lista módulos do Waybar (não lê config inteira)."""
        config = self.read_config()
        import re
        modules = re.findall(r'"modules-(\w+)"\s*:\s*\[(.*?)\]', config, re.DOTALL)
        result = "Waybar modules:\n"
        for position, mods in modules:
            mod_list = [m.strip().strip('"') for m in mods.split(",")]
            result += f"  {position}: {', '.join(mod_list)}\n"
        result += "\nUse 'waybar_read_section' to read specific module config."
        return result

    def read_style(self) -> str:
        """Lista seções de style do Waybar."""
        style_path = self.config_path.parent / "style.css"
        if not style_path.exists():
            return "Waybar style.css not found"

        import re
        content = style_path.read_text()
        selectors = re.findall(r'^([#.][\w\-]+)\s*\{', content, re.MULTILINE)
        return f"CSS selectors: {', '.join(selectors)}\nUse 'waybar_read_section' to read a specific selector."

    def read_section(self, section: str, file_type: str) -> str:
        """Lê seção específica de config ou style."""
        if file_type == "config":
            config = self.read_config()
            import re
            # Tenta encontrar módulo [section]
            pattern = r'"' + re.escape(section) + r'"\s*:\s*\{(.*?)(?=\n\s*"[^"]*"\s*:|$)}'
            match = re.search(pattern, config, re.DOTALL)
            if match:
                return f"Module '{section}' config:\n{match.group(0)}"
            return f"Module '{section}' not found in config"
        else:  # style
            style_path = self.config_path.parent / "style.css"
            if not style_path.exists():
                return "style.css not found"
            content = style_path.read_text()
            import re
            # Busca selector { ... }
            pattern = re.escape(section) + r'\s*\{(.*?)\}'
            match = re.search(pattern, content, re.DOTALL)
            if match:
                return f"CSS selector '{section}':\n{match.group(0)}"
            return f"Selector '{section}' not found in style.css"

    def add_module(self, module_name: str, position: str) -> str:
        """Adiciona um módulo ao Waybar (implementação simplificada)."""
        config = self.read_config()

        # Esta é uma implementação simplificada - idealmente parsearia JSON
        # e adicionaria corretamente. Por enquanto retorna instrução.
        return (
            f"To add module '{module_name}' to {position}:\n"
            f"1. Edit {self.config_path}\n"
            f'2. Add "{module_name}" to the {position} array in the config'
        )
