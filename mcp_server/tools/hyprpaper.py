"""Tools para manipular configuração do Hyprpaper."""

from pathlib import Path
from .base import BaseTool


class HyperpaperTools(BaseTool):
    """Tools para Hyprpaper - gerencia hyprpaper.conf."""

    def __init__(self):
        config_path = Path.home() / ".config/hypr/hyprpaper.conf"
        if not config_path.exists():
            # Cria um config vazio
            config_path.parent.mkdir(parents=True, exist_ok=True)
            config_path.touch()
        self.config_path = config_path

    def get_tools(self) -> dict:
        """Retorna os tools disponíveis para Hyprpaper."""
        return {
            "hyprpaper_read_config": {
                "description": "Lê a configuração do Hyprpaper",
                "schema": {"type": "object", "properties": {}},
                "function": self.read_config_tool,
            },
            "hyprpaper_set_wallpaper": {
                "description": "Define a imagem de wallpaper para um monitor",
                "schema": {
                    "type": "object",
                    "properties": {
                        "monitor": {
                            "type": "string",
                            "description": "Nome do monitor (ex: HDMI-1, eDP-1 ou 'all' para todos)"
                        },
                        "path": {
                            "type": "string",
                            "description": "Caminho absoluto para a imagem"
                        },
                    },
                    "required": ["monitor", "path"],
                },
                "function": self.set_wallpaper,
            },
            "hyprpaper_backup": {
                "description": "Faz backup da configuração do Hyprpaper",
                "schema": {"type": "object", "properties": {}},
                "function": lambda: self.backup(),
            },
        }

    def read_config_tool(self) -> str:
        """Lê a config do Hyprpaper."""
        if self.config_path.stat().st_size == 0:
            return "Hyprpaper config is empty"
        config = self.read_config()
        return f"Hyprpaper config:\n\n{config}"

    def set_wallpaper(self, monitor: str, path: str) -> str:
        """Define o wallpaper para um monitor."""
        config = self.read_config() if self.config_path.stat().st_size > 0 else ""

        # Verifica se o arquivo existe
        from pathlib import Path
        if not Path(path).exists():
            return f"Image file not found: {path}"

        # Adiciona ou atualiza a linha preload
        import re

        if "preload" in config:
            # Atualiza se já existe
            new_config = config
        else:
            # Adiciona preload
            new_config = config + "\npreload = " + path

        # Adiciona wallpaper para o monitor
        wallpaper_line = f"wallpaper = {monitor},{path}"
        if f"wallpaper = {monitor}" in new_config:
            # Atualiza existente
            pattern = rf"wallpaper\s*=\s*{re.escape(monitor)}.*?$"
            new_config = re.sub(pattern, wallpaper_line, new_config, flags=re.MULTILINE)
        else:
            # Adiciona novo
            new_config = new_config + "\n" + wallpaper_line

        self.write_config(new_config)
        return f"Wallpaper set for {monitor}: {path}"
