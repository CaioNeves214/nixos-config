#!/usr/bin/env bash
# Módulo custom da waybar: ícone fixo + temperatura do pacote no texto,
# com a temperatura por núcleo (Core 0, Core 1, ...) no tooltip ao passar
# o mouse.
# Espera `sensors` e `jq` no PATH (injetados pelo wrapper Nix).
set -euo pipefail

ICON="󰔏"

json=$(sensors -j coretemp-isa-0000 2>/dev/null)

package_temp=$(echo "$json" | jq -r '.["coretemp-isa-0000"]["Package id 0"].temp1_input')
package_temp_int=${package_temp%.*}

tooltip=$(echo "$json" | jq -r '
  .["coretemp-isa-0000"]
  | to_entries[]
  | select(.key | startswith("Core"))
  | "\(.key): \(.value | to_entries[] | select(.key | endswith("_input")) | (.value | floor))°C"
')

jq -nc --arg text "$ICON ${package_temp_int}°C" --arg tooltip "$tooltip" \
  '{text: $text, tooltip: $tooltip}'
