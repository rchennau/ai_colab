#!/usr/bin/env bash
# hcom Atari-8bit Hardware Register Initialization
# Populates the Blackboard with standard Atari 8-bit constants

set -euo pipefail

# Find script directory and source utils
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../scripts/utils.sh"

KV_TOOL="$SCRIPT_DIR/hcom-kv"

echo "Initializing Atari hardware constants in Blackboard..."

# ANTIC
"$KV_TOOL" set atari_reg_DMACTL '$D400'
"$KV_TOOL" set atari_reg_CHACTL '$D401'
"$KV_TOOL" set atari_reg_DLISTL '$D402'
"$KV_TOOL" set atari_reg_DLISTH '$D403'
"$KV_TOOL" set atari_reg_HSCROL '$D404'
"$KV_TOOL" set atari_reg_VSCROL '$D405'
"$KV_TOOL" set atari_reg_PMBASE '$D407'
"$KV_TOOL" set atari_reg_CHBASE '$D409'
"$KV_TOOL" set atari_reg_WSYNC  '$D40A'
"$KV_TOOL" set atari_reg_VCOUNT '$D40B'
"$KV_TOOL" set atari_reg_NMIEN  '$D40E'
"$KV_TOOL" set atari_reg_NMIST  '$D40F'

# GTIA
"$KV_TOOL" set atari_reg_HPOSP0 '$D000'
"$KV_TOOL" set atari_reg_HPOSP1 '$D001'
"$KV_TOOL" set atari_reg_HPOSP2 '$D002'
"$KV_TOOL" set atari_reg_HPOSP3 '$D003'
"$KV_TOOL" set atari_reg_HPOSM0 '$D004'
"$KV_TOOL" set atari_reg_HPOSM1 '$D005'
"$KV_TOOL" set atari_reg_HPOSM2 '$D006'
"$KV_TOOL" set atari_reg_HPOSM3 '$D007'
"$KV_TOOL" set atari_reg_SIZEP0 '$D008'
"$KV_TOOL" set atari_reg_SIZEP1 '$D009'
"$KV_TOOL" set atari_reg_SIZEP2 '$D00A'
"$KV_TOOL" set atari_reg_SIZEP3 '$D00B'
"$KV_TOOL" set atari_reg_COLPM0 '$D012'
"$KV_TOOL" set atari_reg_COLPM1 '$D013'
"$KV_TOOL" set atari_reg_COLPM2 '$D014'
"$KV_TOOL" set atari_reg_COLPM3 '$D015'
"$KV_TOOL" set atari_reg_COLPF0 '$D016'
"$KV_TOOL" set atari_reg_COLPF1 '$D017'
"$KV_TOOL" set atari_reg_COLPF2 '$D018'
"$KV_TOOL" set atari_reg_COLPF3 '$D019'
"$KV_TOOL" set atari_reg_COLBK  '$D01A'
"$KV_TOOL" set atari_reg_PRIOR  '$D01B'
"$KV_TOOL" set atari_reg_GRACTL '$D01D'
"$KV_TOOL" set atari_reg_CONSOL '$D01F'

# POKEY
"$KV_TOOL" set atari_reg_AUDF1  '$D200'
"$KV_TOOL" set atari_reg_AUDC1  '$D201'
"$KV_TOOL" set atari_reg_AUDF2  '$D202'
"$KV_TOOL" set atari_reg_AUDC2  '$D203'
"$KV_TOOL" set atari_reg_AUDF3  '$D204'
"$KV_TOOL" set atari_reg_AUDC3  '$D205'
"$KV_TOOL" set atari_reg_AUDF4  '$D206'
"$KV_TOOL" set atari_reg_AUDC4  '$D207'
"$KV_TOOL" set atari_reg_AUDCTL '$D208'
"$KV_TOOL" set atari_reg_STTIMER '$D209'
"$KV_TOOL" set atari_reg_SKRES  '$D20A'
"$KV_TOOL" set atari_reg_POTGO  '$D20B'
"$KV_TOOL" set atari_reg_SEROUT '$D20D'
"$KV_TOOL" set atari_reg_IRQEN  '$D20E'
"$KV_TOOL" set atari_reg_IRQST  '$D20F'
"$KV_TOOL" set atari_reg_SKCTL  '$D20F'
"$KV_TOOL" set atari_reg_RANDOM '$D20A'

# OS Shadow Registers
"$KV_TOOL" set atari_shadow_RTCLOK '$0012'
"$KV_TOOL" set atari_shadow_SDMCTL '$022F'
"$KV_TOOL" set atari_shadow_SDLSTL '$0230'
"$KV_TOOL" set atari_shadow_SDLSTH '$0231'
"$KV_TOOL" set atari_shadow_COLOR0 '$02C4'
"$KV_TOOL" set atari_shadow_COLOR1 '$02C5'
"$KV_TOOL" set atari_shadow_COLOR2 '$02C6'
"$KV_TOOL" set atari_shadow_COLOR3 '$02C7'
"$KV_TOOL" set atari_shadow_COLOR4 '$02C8'

echo "Hardware constants initialization complete."
