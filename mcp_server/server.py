#!/usr/bin/env python3
"""
MCP Server para ricing NixOS + Hyprland.
Implementa JSON-RPC 2.0 conforme o protocolo MCP.
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
from .tools.theme import ThemeTools

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stderr)]
)
logger = logging.getLogger(__name__)


class RicingMCPServer:
    def __init__(self):
        self.tools = {}
        self._register_tools()

    def _register_tools(self):
        tool_classes = [HyprlandTools, KittyTools, WaybarTools, HyperpaperTools, ThemeTools]
        for cls in tool_classes:
            try:
                instance = cls()
                self.tools.update(instance.get_tools())
            except Exception as e:
                logger.warning(f"Could not load {cls.__name__}: {e}")

        logger.info(f"Registered {len(self.tools)} tools")

    def _ok(self, request_id: Any, result: Any) -> dict:
        return {"jsonrpc": "2.0", "id": request_id, "result": result}

    def _err(self, request_id: Any, code: int, message: str) -> dict:
        return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}

    def handle_request(self, request: dict) -> dict | None:
        request_id = request.get("id")
        method = request.get("method", "")
        params = request.get("params", {})

        # Notifications (no id) — don't respond
        if "id" not in request:
            return None

        if method == "initialize":
            return self._ok(request_id, {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {},
                },
                "serverInfo": {
                    "name": "nix-ricing-mcp",
                    "version": "0.1.0",
                },
            })

        elif method == "tools/list":
            tools_list = []
            for name, tool in self.tools.items():
                tools_list.append({
                    "name": name,
                    "description": tool.get("description", ""),
                    "inputSchema": tool.get("schema", {"type": "object", "properties": {}}),
                })
            return self._ok(request_id, {"tools": tools_list})

        elif method == "tools/call":
            tool_name = params.get("name")
            arguments = params.get("arguments", {})

            if tool_name not in self.tools:
                return self._err(request_id, -32601, f"Tool not found: {tool_name}")

            try:
                result = self.tools[tool_name]["function"](**arguments)
                return self._ok(request_id, {
                    "content": [{"type": "text", "text": str(result)}]
                })
            except Exception as e:
                logger.error(f"Error calling tool {tool_name}: {e}", exc_info=True)
                return self._err(request_id, -32603, str(e))

        elif method == "ping":
            return self._ok(request_id, {})

        else:
            return self._err(request_id, -32601, f"Method not found: {method}")


def main():
    server = RicingMCPServer()
    logger.info("Starting MCP Server for NixOS Ricing...")

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            request = json.loads(line)
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON: {e}")
            response = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "Parse error"}}
            print(json.dumps(response), flush=True)
            continue

        try:
            response = server.handle_request(request)
            if response is not None:
                print(json.dumps(response), flush=True)
        except Exception as e:
            logger.error(f"Unhandled error: {e}", exc_info=True)
            response = {"jsonrpc": "2.0", "id": request.get("id"), "error": {"code": -32603, "message": str(e)}}
            print(json.dumps(response), flush=True)


if __name__ == "__main__":
    main()
