#!/bin/bash
# 独立功能模块加载入口
# 用法：在主脚本中 source 此文件，然后调用 run_mods

MODS_DIR="./mods"

source "$MODS_DIR/vibrator_fix.sh"
source "$MODS_DIR/replace_kernel.sh"
# source "$MODS_DIR/perfmgr_engine.sh"  # OS4 暂不支持
# source "$MODS_DIR/wildboost_engine.sh"  # OS4 暂不支持

run_mods() {
    echo -e "\n========================================"
    echo "  功能模块"
    echo "========================================"

    mod_vibrator_fix
    # mod_perfmgr_engine  # OS4 暂不支持
    # mod_wildboost_engine  # OS4 暂不支持

    echo -e "\n  功能模块处理完成"
}
