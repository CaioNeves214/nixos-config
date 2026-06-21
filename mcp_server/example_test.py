#!/usr/bin/env python3
"""Exemplo interativo de como usar o MCP Server."""

import json
import subprocess
import sys


def interactive_test():
    """Teste interativo do MCP Server."""

    proc = subprocess.Popen(
        [sys.executable, "-m", "mcp_server"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )

    def send_message(msg: dict) -> dict:
        """Envia mensagem e recebe resposta."""
        proc.stdin.write(json.dumps(msg) + "\n")
        proc.stdin.flush()
        response_line = proc.stdout.readline()
        if response_line:
            return json.loads(response_line)
        return {}

    try:
        print("=" * 70)
        print("MCP Server Interactive Test")
        print("=" * 70)
        print()

        # Initialize
        resp = send_message({"type": "initialize"})
        print(f"✓ Initialized: {resp.get('serverInfo', {}).get('name')}")
        print()

        # List all tools
        resp = send_message({"type": "tools/list"})
        tools = {t["name"]: t for t in resp.get("tools", [])}
        
        print(f"Available Tools: {len(tools)}")
        print()
        
        # Test each category
        categories = {
            "Hyprland": [k for k in tools.keys() if "hyprland" in k],
            "Kitty": [k for k in tools.keys() if "kitty" in k],
            "Waybar": [k for k in tools.keys() if "waybar" in k],
            "Hyprpaper": [k for k in tools.keys() if "hyprpaper" in k],
        }

        for category, tool_list in categories.items():
            if tool_list:
                print(f"{category}:")
                for tool in sorted(tool_list):
                    desc = tools[tool].get("description", "No description")
                    print(f"  • {tool}")
                    print(f"    {desc}")
                print()

        # Example: Read Hyprland config
        print("-" * 70)
        print("Example: Reading Hyprland Configuration")
        print("-" * 70)
        resp = send_message({
            "type": "tools/call",
            "name": "hyprland_read_config",
            "arguments": {}
        })
        content = resp.get("content", [{}])[0].get("text", "")
        lines = content.split("\n")
        print(f"✓ Read {len(lines)} lines of config")
        print("\nFirst 10 lines:")
        for line in lines[:10]:
            print(f"  {line}")
        print()

        # Example: Get a variable
        print("-" * 70)
        print("Example: Getting a Variable")
        print("-" * 70)
        resp = send_message({
            "type": "tools/call",
            "name": "hyprland_get_variable",
            "arguments": {"var_name": "$terminal"}
        })
        print(f"✓ {resp.get('content', [{}])[0].get('text', 'N/A')}")
        print()

        print("=" * 70)
        print("All tests completed successfully!")
        print("=" * 70)

    finally:
        proc.terminate()
        proc.wait(timeout=5)


if __name__ == "__main__":
    interactive_test()
