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
        }

    def read_config_tool(self) -> str:
        """Lê a config do Kitty."""
        if self.config_path.stat().st_size == 0:
            return "Kitty config is empty"
        config = self.read_config()
        return f"Kitty config:\n\n{config}"

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
