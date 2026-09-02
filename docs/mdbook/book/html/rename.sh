#!/usr/bin/env bash
set -euo pipefail

# 1. Swap directory names using a temp folder
mv part-05-building-physical-systems part-temp
mv part-06-geometry-becomes-code part-05-geometry-becomes-code
mv part-temp part-06-building-physical-systems

# 2. Swap internal references in SUMMARY.md
sed -i \
  -e 's/part-05-building-physical-systems/part-TEMP-holder/g' \
  -e 's/part-06-geometry-becomes-code/part-05-geometry-becomes-code/g' \
  -e 's/part-TEMP-holder/part-06-building-physical-systems/g' \
  -e 's/Part V: Building Physical Systems/Part V: TEMP_PHYSICAL/g' \
  -e 's/Part VI: Geometry Becomes Code/Part V: Geometry Becomes Code/g' \
  -e 's/Part V: TEMP_PHYSICAL/Part VI: Building Physical Systems/g' \
  SUMMARY.md

echo "Successfully swapped Part 05 and Part 06!"


chmod +x swap_parts.sh && ./swap_parts.sh && rm swap_parts.sh