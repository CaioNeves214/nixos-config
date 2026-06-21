"""Tools para manipular configuração do Hyprland."""

import os
import re
from pathlib import Path
from .base import BaseTool


class HyprlandTools(BaseTool):
    """Tools para Hyprland - gerencia hyprland.conf."""

    def __init__(self):
        # Determina o caminho do config dinamicamente
        config_path = Path.home() / ".config/hypr/hyprland.conf"

        # Se não existir, tenta o caminho do dotfiles
        if not config_path.exists():
            config_path = Path(__file__).parent.parent.parent / "dotfiles/hypr/hyprland.conf"

        if not config_path.exists():
            raise FileNotFoundError("hyprland.conf not found")

        self.config_path = config_path

    def get_tools(self) -> dict:
        """Retorna os tools disponíveis para Hyprland."""
        return {
            "hyprland_read_config": {
                "description": "Lê a configuração completa do Hyprland",
                "schema": {"type": "object", "properties": {}},
                "function": self.read_config_tool,
            },
            "hyprland_get_variable": {
                "description": "Obtém o valor de uma variável no Hyprland (ex: $terminal, $menu)",
                "schema": {
                    "type": "object",
                    "properties": {
                        "var_name": {"type": "string", "description": "Nome da variável (com $)"}
                    },
                    "required": ["var_name"],
                },
                "function": self.get_variable,
            },
            "hyprland_set_variable": {
                "description": "Define uma variável no Hyprland",
                "schema": {
                    "type": "object",
                    "properties": {
                        "var_name": {"type": "string", "description": "Nome da variável (com $)"},
                        "value": {"type": "string", "description": "Novo valor"},
                    },
                    "required": ["var_name", "value"],
                },
                "function": self.set_variable,
            },
            "hyprland_set_keybind": {
                "description": "Define um keybind no Hyprland",
                "schema": {
                    "type": "object",
                    "properties": {
                        "modifier": {"type": "string", "description": "Modificadores (ex: SUPER, SUPER_SHIFT, CTRL)"},
                        "key": {"type": "string", "description": "Tecla (ex: Return, F, D)"},
                        "action": {"type": "string", "description": "Ação (ex: exec, killactive, movefocus)"},
                        "command": {"type": "string", "description": "Comando a executar (só para exec)"},
                    },
                    "required": ["modifier", "key", "action"],
                },
                "function": self.set_keybind,
            },
            "hyprland_get_section": {
                "description": "Obtém uma seção específica da config (ex: general, input, gestures)",
                "schema": {
                    "type": "object",
                    "properties": {
                        "section_name": {"type": "string", "description": "Nome da seção (ex: general, input, gestures)"},
                    },
                    "required": ["section_name"],
                },
                "function": self.get_section_tool,
            },
            "hyprland_update_section": {
                "description": "Atualiza uma seção da config do Hyprland",
                "schema": {
                    "type": "object",
                    "properties": {
                        "section_name": {"type": "string", "description": "Nome da seção"},
                        "properties": {
                            "type": "object",
                            "description": "Dict com propriedades a atualizar (key: value)",
                        },
                    },
                    "required": ["section_name", "properties"],
                },
                "function": self.update_section_tool,
            },
            "hyprland_backup": {
                "description": "Faz backup da configuração atual do Hyprland",
                "schema": {"type": "object", "properties": {}},
                "function": lambda: self.backup(),
            },
            "hyprland_search_keybind": {
                "description": "Busca um keybind específico (por modifier+key)",
                "schema": {
                    "type": "object",
                    "properties": {
                        "modifier": {"type": "string", "description": "Modificador (ex: SUPER, CTRL)"},
                        "key": {"type": "string", "description": "Tecla (ex: Return, F)"},
                    },
                    "required": ["modifier", "key"],
                },
                "function": self.search_keybind,
            },
        }

    def read_config_tool(self) -> str:
        """Lista seções disponíveis (não lê tudo)."""
        config = self.read_config()
        sections = ["general", "input", "decoration", "animations", "gestures", "env", "bind", "monitor"]
        available = []
        for section in sections:
            if self.find_section(config, section):
                available.append(section)
        return f"Available sections: {', '.join(available)}\nUse 'hyprland_get_section' to read a specific section."

    def get_variable(self, var_name: str) -> str:
        """Obtém o valor de uma variável."""
        config = self.read_config()
        # Busca "$var_name = value"
        pattern = rf"^\s*{re.escape(var_name)}\s*=\s*(.+?)$"
        match = re.search(pattern, config, re.MULTILINE)
        if match:
            return f"{var_name} = {match.group(1).strip()}"
        return f"Variable '{var_name}' not found"

    def set_variable(self, var_name: str, value: str) -> str:
        """Define uma variável."""
        config = self.read_config()

        # Remove o $ do inicio se incluído
        clean_name = var_name.lstrip("$")

        # Busca e substitui a variável existente
        pattern = rf"^\s*\${re.escape(clean_name)}\s*=\s*.+?$"
        match = re.search(pattern, config, re.MULTILINE)

        if match:
            # Substitui a linha existente
            new_config = config[:match.start()] + f"${clean_name} = {value}" + config[match.end():]
        else:
            # Adiciona no início após comentários
            lines = config.split("\n")
            insert_idx = 0
            for i, line in enumerate(lines):
                if not line.strip().startswith("#") and line.strip():
                    insert_idx = i
                    break
            lines.insert(insert_idx, f"${clean_name} = {value}")
            new_config = "\n".join(lines)

        self.write_config(new_config)
        return f"Variable ${clean_name} set to '{value}'"

    def set_keybind(self, modifier: str, key: str, action: str, command: str = "") -> str:
        """Define um keybind."""
        config = self.read_config()

        # Busca a seção de bind
        bind_pattern = r"bind\s*=.*"
        last_bind = None
        for match in re.finditer(bind_pattern, config):
            last_bind = match

        if command and action == "exec":
            keybind = f'bind = {modifier},{key},exec,{command}'
        else:
            keybind = f'bind = {modifier},{key},{action}'

        if last_bind:
            # Adiciona após o último bind
            insert_pos = last_bind.end()
            new_config = config[:insert_pos] + "\n" + keybind + config[insert_pos:]
        else:
            # Adiciona na seção general
            general_section = self.find_section(config, "general")
            if general_section:
                insert_pos = general_section[1]
                new_config = config[:insert_pos] + "\n" + keybind + config[insert_pos:]
            else:
                new_config = config + "\n" + keybind

        self.write_config(new_config)
        return f"Keybind set: {modifier}+{key} -> {action}"

    def get_section_tool(self, section_name: str) -> str:
        """Obtém uma seção."""
        config = self.read_config()
        section = self.find_section(config, section_name)
        if section:
            start, end = section
            section_content = config[start:end]
            return f"Section '{section_name}':\n\n{section_content}"
        return f"Section '{section_name}' not found"

    def search_keybind(self, modifier: str, key: str) -> str:
        """Busca um keybind específico."""
        config = self.read_config()
        pattern = rf"bind\s*=\s*{re.escape(modifier)}\s*,\s*{re.escape(key)}\s*,(.+?)(?=\n|$)"
        match = re.search(pattern, config, re.MULTILINE)
        if match:
            full_bind = match.group(0)
            return f"Found: {full_bind}"
        return f"Keybind {modifier}+{key} not found"

    def update_section_tool(self, section_name: str, properties: dict) -> str:
        """Atualiza uma seção com novas propriedades."""
        config = self.read_config()
        section = self.find_section(config, section_name)

        if not section:
            return f"Section '{section_name}' not found"

        start, end = section
        section_content = config[start:end]

        # Atualiza propriedades existentes ou adiciona novas
        updated_section = section_content
        for key, value in properties.items():
            # Busca a propriedade na seção
            prop_pattern = rf"^\s*{re.escape(key)}\s*=\s*.+?$"
            match = re.search(prop_pattern, updated_section, re.MULTILINE)

            if match:
                # Substitui a linha existente
                updated_section = (
                    updated_section[:match.start()] +
                    f"{key} = {value}" +
                    updated_section[match.end():]
                )
            else:
                # Adiciona antes do fechamento da seção
                closing_brace = updated_section.rfind("}")
                if closing_brace != -1:
                    updated_section = (
                        updated_section[:closing_brace] +
                        f"\n    {key} = {value}\n" +
                        updated_section[closing_brace:]
                    )

        new_config = config[:start] + updated_section + config[end:]
        self.write_config(new_config)

        return f"Section '{section_name}' updated with {len(properties)} properties"
