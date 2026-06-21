#!/usr/bin/env python3
"""
MCP Server para ricing NixOS + Hyprland.
Implementa o protocolo MCP com tools para diferentes componentes do sistema.
"""

import json
import sys
import logging
from typing import Any
from pathlib import Path

from .tools.hyprland import HyprlandTools
from .tools.kitty import KittyTools
from .tools.waybar import WaybarTools
from .tools.hyprpaper import HyperpaperTools

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stderr)]
)
logger = logging.getLogger(__name__)


class RicingMCPServer:
    def __init__(self):
        self.tools = {}
        self._register_tools()

    def _register_tools(self):
        """Registra todos os tools disponíveis."""
        hyprland = HyprlandTools()
        kitty = KittyTools()
        waybar = WaybarTools()
        hyprpaper = HyperpaperTools()

        # Hyprland tools
        self.tools.update(hyprland.get_tools())

        # Kitty tools
        self.tools.update(kitty.get_tools())

        # Waybar tools
        self.tools.update(waybar.get_tools())

        # Hyprpaper tools
        self.tools.update(hyprpaper.get_tools())

        logger.info(f"Registered {len(self.tools)} tools")

    def handle_message(self, message: dict[str, Any]) -> dict[str, Any]:
        """Processa mensagens do protocolo MCP."""
        msg_type = message.get("type")

        if msg_type == "initialize":
            return self._handle_initialize(message)
        elif msg_type == "resources/read":
            return self._handle_resources_read(message)
        elif msg_type == "tools/list":
            return self._handle_tools_list(message)
        elif msg_type == "tools/call":
            return self._handle_tools_call(message)
        else:
            return {"error": f"Unknown message type: {msg_type}"}

    def _handle_initialize(self, message: dict) -> dict:
        """Retorna informações sobre o servidor MCP."""
        return {
            "protocolVersion": "2024-11-05",
            "capabilities": {
                "tools": {},
                "resources": {},
            },
            "serverInfo": {
                "name": "nix-ricing-mcp",
                "version": "0.1.0",
            },
        }

    def _handle_tools_list(self, message: dict) -> dict:
        """Lista todos os tools disponíveis."""
        tools_list = []
        for tool_name, tool_func in self.tools.items():
            tools_list.append({
                "name": tool_name,
                "description": tool_func.get("description", ""),
                "inputSchema": tool_func.get("schema", {}),
            })
        return {"tools": tools_list}

    def _handle_tools_call(self, message: dict) -> dict:
        """Executa um tool chamado."""
        tool_name = message.get("name")
        arguments = message.get("arguments", {})

        if tool_name not in self.tools:
            return {"error": f"Tool not found: {tool_name}"}

        try:
            tool_func = self.tools[tool_name]["function"]
            result = tool_func(**arguments)
            return {"content": [{"type": "text", "text": result}]}
        except Exception as e:
            logger.error(f"Error calling tool {tool_name}: {e}", exc_info=True)
            return {"error": str(e)}

    def _handle_resources_read(self, message: dict) -> dict:
        """Lê recursos (arquivos de config)."""
        uri = message.get("uri", "")

        try:
            path = Path(uri.replace("file://", ""))
            if path.exists():
                content = path.read_text()
                return {"contents": [{"uri": uri, "mimeType": "text/plain", "text": content}]}
            else:
                return {"error": f"File not found: {uri}"}
        except Exception as e:
            logger.error(f"Error reading resource {uri}: {e}")
            return {"error": str(e)}


def main():
    """Função principal — lê JSON do stdin e responde no stdout."""
    server = RicingMCPServer()

    logger.info("Starting MCP Server for NixOS Ricing...")

    try:
        while True:
            line = sys.stdin.readline()
            if not line:
                break

            try:
                message = json.loads(line)
                response = server.handle_message(message)
                print(json.dumps(response), flush=True)
            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON: {e}")
                print(json.dumps({"error": "Invalid JSON"}), flush=True)
            except Exception as e:
                logger.error(f"Error processing message: {e}", exc_info=True)
                print(json.dumps({"error": str(e)}), flush=True)

    except KeyboardInterrupt:
        logger.info("Shutting down...")
        sys.exit(0)


if __name__ == "__main__":
    main()
