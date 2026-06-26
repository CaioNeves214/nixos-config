"""Tools para o design system de cores (wallust)."""

import re
import shutil
import subprocess
from pathlib import Path
from .base import BaseTool

# As 5 cores do design system (ordem de exibição).
TOKENS = ["base", "text", "primary", "secondary", "alert"]


class ThemeTools(BaseTool):
    """Tools para a paleta derivada do wallpaper.

    Fonte da paleta: ~/.config/waybar/colors.css (gerado por wallust),
    que contém os 5 tokens semânticos via @define-color.
    """

    def __init__(self):
        self.palette_path = Path.home() / ".config/waybar/colors.css"
        self.wallpaper_dir = Path.home() / ".config/wallpapers"

    def get_tools(self) -> dict:
        return {
            "theme_read_palette": {
                "description": "Lê as 5 cores atuais do design system (base, text, primary, secondary, alert)",
                "schema": {"type": "object", "properties": {}},
                "function": self.read_palette,
            },
            "theme_get_color": {
                "description": "Retorna o valor hex de um único token (economia de tokens)",
                "schema": {
                    "type": "object",
                    "properties": {
                        "role": {
                            "type": "string",
                            "enum": TOKENS,
                            "description": "Token do design system",
                        }
                    },
                    "required": ["role"],
                },
                "function": self.get_color,
            },
            "theme_list_wallpapers": {
                "description": "Lista as imagens disponíveis em ~/.config/wallpapers",
                "schema": {"type": "object", "properties": {}},
                "function": self.list_wallpapers,
            },
            "theme_set_wallpaper": {
                "description": "Aplica um wallpaper, regenera a paleta e recarrega os apps (roda update-theme)",
                "schema": {
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "Nome do arquivo em ~/.config/wallpapers ou caminho absoluto",
                        }
                    },
                    "required": ["name"],
                },
                "function": self.set_wallpaper,
            },
        }

    def _parse_palette(self) -> dict:
        if not self.palette_path.exists():
            return {}
        content = self.palette_path.read_text()
        # @define-color NAME #RRGGBB;
        pairs = dict(re.findall(r'@define-color\s+(\w+)\s+(#[0-9A-Fa-f]{6})\s*;', content))
        return {t: pairs[t] for t in TOKENS if t in pairs}

    def read_palette(self) -> str:
        palette = self._parse_palette()
        if not palette:
            return ("Nenhuma paleta gerada ainda. "
                    "Rode 'update-theme <imagem>' ou 'theme_set_wallpaper'.")
        return "Paleta atual:\n" + "\n".join(f"  {k:10} {v}" for k, v in palette.items())

    def get_color(self, role: str) -> str:
        palette = self._parse_palette()
        if role not in palette:
            return f"Token '{role}' não encontrado (paleta vazia ou role inválido)."
        return palette[role]

    def list_wallpapers(self) -> str:
        if not self.wallpaper_dir.exists():
            return "Diretório de wallpapers não encontrado."
        exts = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
        imgs = sorted(p.name for p in self.wallpaper_dir.iterdir() if p.suffix.lower() in exts)
        if not imgs:
            return f"Nenhuma imagem em {self.wallpaper_dir}."
        return "Wallpapers:\n" + "\n".join(f"  {i}" for i in imgs)

    def set_wallpaper(self, name: str) -> str:
        if not shutil.which("update-theme"):
            return "Comando 'update-theme' não encontrado no PATH (faça o rebuild primeiro)."
        try:
            result = subprocess.run(
                ["update-theme", name],
                capture_output=True, text=True, timeout=120,
            )
        except subprocess.TimeoutExpired:
            return "update-theme excedeu o tempo limite."
        if result.returncode != 0:
            return f"Falha ao aplicar tema:\n{result.stderr.strip()}"
        palette = self.read_palette()
        return f"{result.stdout.strip()}\n\n{palette}"
