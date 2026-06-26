"""Tools para manipular configuração do Waybar."""

from pathlib import Path
import json
import re
from .base import BaseTool


def _strip_jsonc_comments(text: str) -> str:
    """Remove comentários // e /* */ de JSONC."""
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    text = re.sub(r'//[^\n]*', '', text)
    return text


def _parse_config(path: Path) -> dict:
    return json.loads(_strip_jsonc_comments(path.read_text()))


class WaybarTools(BaseTool):
    """Tools para Waybar - gerencia config.jsonc e style.css."""

    def __init__(self):
        config_path = Path.home() / ".config/waybar/config.jsonc"
        if not config_path.exists():
            config_path = Path(__file__).parent.parent.parent / "dotfiles/waybar/config.jsonc"
        if not config_path.exists():
            raise FileNotFoundError("waybar config.jsonc not found")
        self.config_path = config_path
        self.style_path = config_path.parent / "style.css"

    def get_tools(self) -> dict:
        return {
            "waybar_read_config": {
                "description": "Lista módulos do Waybar por posição (left, center, right)",
                "schema": {"type": "object", "properties": {}},
                "function": self.read_config_tool,
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
            "waybar_read_style": {
                "description": "Lista seletores CSS disponíveis no style.css do Waybar",
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
        data = _parse_config(self.config_path)
        result = "Waybar modules:\n"
        for pos in ("left", "center", "right"):
            key = f"modules-{pos}"
            if key in data:
                result += f"  {pos}: {', '.join(data[key])}\n"
        result += "\nUse 'waybar_read_section' with file_type='config' to read a specific module."
        return result

    def read_section(self, section: str, file_type: str) -> str:
        if file_type == "config":
            return self._read_config_section(section)
        else:
            return self._read_style_section(section)

    def _read_config_section(self, section: str) -> str:
        data = _parse_config(self.config_path)
        if section not in data:
            available = [k for k in data if not k.startswith("modules-") and k not in ("layer", "position", "height", "margin-top", "margin-left", "margin-right", "spacing")]
            return f"Module '{section}' not found.\nAvailable modules: {', '.join(available)}"
        return f"Module '{section}':\n{json.dumps({section: data[section]}, indent=4, ensure_ascii=False)}"

    def _read_style_section(self, section: str) -> str:
        if not self.style_path.exists():
            return "style.css not found"
        content = self.style_path.read_text()

        # Encontra todos os blocos CSS onde o seletor aparece (ex: "#backlight" pode estar em bloco multi-seletor)
        blocks = []
        # Divide em blocos { ... }
        pattern = re.compile(r'([^{}]+)\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}', re.DOTALL)
        for match in pattern.finditer(content):
            selectors_raw = match.group(1)
            body = match.group(2)
            # Verifica se o seletor buscado está entre os seletores do bloco
            selectors = [s.strip() for s in selectors_raw.split(',')]
            if any(s == section or s.startswith(section + ':') or s.startswith(section + ' ') for s in selectors):
                block = selectors_raw.strip() + ' {' + body + '}'
                blocks.append(block)

        if not blocks:
            return f"Selector '{section}' not found in style.css"
        return f"CSS rules for '{section}':\n\n" + "\n\n".join(blocks)

    def read_style(self) -> str:
        if not self.style_path.exists():
            return "style.css not found"
        content = self.style_path.read_text()
        # Extrai comentários de seção (/* ── Titulo ── */)
        sections = re.findall(r'/\*\s*──\s*(.+?)\s*─+\s*\*/', content)
        # Extrai seletores únicos
        selectors = []
        for match in re.finditer(r'^([#.*][\w\-#., >:]+)\s*\{', content, re.MULTILINE):
            for s in match.group(1).split(','):
                s = s.strip()
                if s and s not in selectors:
                    selectors.append(s)
        result = "Style sections: " + ", ".join(sections) + "\n"
        result += "CSS selectors: " + ", ".join(selectors) + "\n"
        result += "\nUse 'waybar_read_section' with file_type='style' to read a specific selector."
        return result

    def add_module(self, module_name: str, position: str) -> str:
        return (
            f"To add module '{module_name}' to {position}:\n"
            f"1. Edit {self.config_path}\n"
            f'2. Add "{module_name}" to the modules-{position} array\n'
            f"3. Add the module config block as a top-level key"
        )
