"""Tools para manipular configuração do Kitty."""

from pathlib import Path
from .base import BaseTool


class KittyTools(BaseTool):
    """Tools para Kitty - gerencia kitty.conf."""

    def __init__(self):
        config_path = Path.home() / ".config/kitty/kitty.conf"
        if not config_path.exists():
            # Cria um config vazio se não existir (será criado depois)
            config_path.parent.mkdir(parents=True, exist_ok=True)
            config_path.touch()
        self.config_path = config_path

    def get_tools(self) -> dict:
        """Retorna os tools disponíveis para Kitty."""
        return {
            "kitty_read_config": {
                "description": "Lê a configuração do Kitty",
                "schema": {"type": "object", "properties": {}},
                "function": self.read_config_tool,
            },
            "kitty_set_option": {
                "description": "Define uma opção no Kitty (ex: font_size, foreground, background)",
                "schema": {
                    "type": "object",
                    "properties": {
                        "option": {"type": "string", "description": "Nome da opção"},
                        "value": {"type": "string", "description": "Novo valor"},
                    },
                    "required": ["option", "value"],
                },
                "function": self.set_option,
            },
            "kitty_backup": {
                "description": "Faz backup da configuração do Kitty",
                "schema": {"type": "object", "properties": {}},
                "function": lambda: self.backup(),
            },
            "kitty_search_option": {
                "description": "Busca o valor atual de uma opção específica",
                "schema": {
                    "type": "object",
                    "properties": {
                        "option": {"type": "string", "description": "Nome da opção (ex: font_size, foreground)"},
                    },
                    "required": ["option"],
                },
                "function": self.search_option,
            },
        }

    def read_config_tool(self) -> str:
        """Lista categorias de opções do Kitty."""
        if self.config_path.stat().st_size == 0:
            return "Kitty config is empty"
        config = self.read_config()
        import re
        options = re.findall(r'^(\w+)\s+', config, re.MULTILINE)
        categories = {
            'font': [o for o in options if 'font' in o or 'size' in o],
            'colors': [o for o in options if 'color' in o or 'background' in o or 'foreground' in o],
            'window': [o for o in options if 'window' in o or 'padding' in o],
            'other': [o for o in options if o not in sum([[o for o in options if c in o] for c in ['font', 'color', 'background', 'foreground', 'window', 'padding']], [])]
        }
        result = "Kitty config categories:\n"
        for cat, opts in categories.items():
            if opts:
                result += f"  {cat}: {', '.join(sorted(set(opts)))}\n"
        result += "\nUse 'kitty_search_option' to find a specific option."
        return result

    def search_option(self, option: str) -> str:
        """Busca uma opção específica."""
        import re
        if self.config_path.stat().st_size == 0:
            return f"Option '{option}' not found (config is empty)"
        config = self.read_config()
        pattern = rf"^{re.escape(option)}\s+(.+?)$"
        match = re.search(pattern, config, re.MULTILINE)
        if match:
            return f"{option} {match.group(1).strip()}"
        return f"Option '{option}' not found"

    def set_option(self, option: str, value: str) -> str:
        """Define uma opção no Kitty."""
        import re

        config = self.read_config() if self.config_path.stat().st_size > 0 else ""

        # Busca a opção existente
        pattern = rf"^{re.escape(option)}\s+.+?$"
        match = re.search(pattern, config, re.MULTILINE)

        if match:
            # Substitui
            new_config = config[:match.start()] + f"{option} {value}" + config[match.end():]
        else:
            # Adiciona no final
            new_config = config + f"\n{option} {value}\n" if config else f"{option} {value}\n"

        self.write_config(new_config)
        return f"Kitty option '{option}' set to '{value}'"
