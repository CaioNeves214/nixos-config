#!/usr/bin/env python3
"""Script para testar o MCP Server localmente."""

import json
import subprocess
import sys


def test_mcp_server():
    """Inicia o servidor e envia alguns testes."""

    # Inicia o servidor como subprocess
    proc = subprocess.Popen(
        [sys.executable, "-m", "mcp_server"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )

    def send_message(msg: dict) -> dict:
        """Envia uma mensagem e recebe a resposta."""
        proc.stdin.write(json.dumps(msg) + "\n")
        proc.stdin.flush()
        response_line = proc.stdout.readline()
        if response_line:
            return json.loads(response_line)
        return {}

    try:
        print("Testing MCP Server...")
        print()

        # Test 1: Initialize
        print("1. Testing initialize...")
        resp = send_message({"type": "initialize"})
        print(f"   Response: {resp.get('serverInfo', {}).get('name')} v{resp.get('serverInfo', {}).get('version')}")
        assert resp.get("serverInfo", {}).get("name") == "nix-ricing-mcp"
        print("   ✓ Initialize OK")
        print()

        # Test 2: List tools
        print("2. Testing tools/list...")
        resp = send_message({"type": "tools/list"})
        tools = resp.get("tools", [])
        print(f"   Found {len(tools)} tools")
        print("   Sample tools:")
        for tool in tools[:5]:
            print(f"     - {tool['name']}")
        assert len(tools) > 0
        print("   ✓ Tools list OK")
        print()

        # Test 3: Call hyprland_read_config
        print("3. Testing hyprland_read_config...")
        resp = send_message({
            "type": "tools/call",
            "name": "hyprland_read_config",
            "arguments": {}
        })
        content = resp.get("content", [{}])[0].get("text", "")
        print(f"   Config size: {len(content)} chars")
        assert len(content) > 0
        print("   ✓ hyprland_read_config OK")
        print()

        print("All tests passed! ✓")

    except Exception as e:
        print(f"Test failed: {e}")
        sys.exit(1)

    finally:
        proc.terminate()
        proc.wait(timeout=5)


if __name__ == "__main__":
    test_mcp_server()
