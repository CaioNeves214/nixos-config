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
        }

    def read_config_tool(self) -> str:
        """Lê a config do Waybar."""
        config = self.read_config()
        return f"Waybar config:\n\n{config}"

    def read_style(self) -> str:
        """Lê o CSS do Waybar."""
        style_path = self.config_path.parent / "style.css"
        if style_path.exists():
            return f"Waybar style.css:\n\n{style_path.read_text()}"
        return "Waybar style.css not found"

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
