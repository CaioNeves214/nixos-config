"""Classe base para tools MCP."""

from abc import ABC, abstractmethod
from pathlib import Path
import re


class BaseTool(ABC):
    """Classe base para tools que manipulam arquivos de config."""

    def __init__(self, config_path: str):
        self.config_path = Path(config_path)
        if not self.config_path.exists():
            raise FileNotFoundError(f"Config file not found: {config_path}")

    def read_config(self) -> str:
        """Lê o arquivo de config."""
        return self.config_path.read_text()

    def write_config(self, content: str) -> None:
        """Escreve no arquivo de config."""
        self.config_path.write_text(content)

    def backup(self) -> str:
        """Faz backup do arquivo atual."""
        content = self.read_config()
        backup_path = self.config_path.with_suffix(self.config_path.suffix + ".bak")
        backup_path.write_text(content)
        return f"Backup created at {backup_path}"

    def find_section(self, config: str, section_name: str) -> tuple[int, int] | None:
        """Encontra uma seção no config (entre { }).
        Retorna (start, end) ou None se não encontrar.
        """
        # Busca "section_name {"
        pattern = rf"{section_name}\s*\{{"
        match = re.search(pattern, config)
        if not match:
            return None

        start = match.start()
        brace_count = 0
        in_section = False

        for i, char in enumerate(config[match.end() - 1:], start=match.end() - 1):
            if char == "{":
                brace_count += 1
                in_section = True
            elif char == "}":
                brace_count -= 1
                if in_section and brace_count == 0:
                    return (start, i + 1)

        return None

    def update_section(self, config: str, section_name: str, new_content: str) -> str:
        """Atualiza uma seção com novo conteúdo."""
        section = self.find_section(config, section_name)
        if not section:
            raise ValueError(f"Section '{section_name}' not found")

        start, end = section
        return config[:start] + new_content + config[end:]

    def get_section_content(self, config: str, section_name: str) -> str | None:
        """Extrai apenas o conteúdo de uma seção (sem as chaves)."""
        section = self.find_section(config, section_name)
        if not section:
            return None
        start, end = section
        content = config[start:end]
        return content

    @abstractmethod
    def get_tools(self) -> dict:
        """Retorna dict de tools com names, descriptions e functions."""
        pass
