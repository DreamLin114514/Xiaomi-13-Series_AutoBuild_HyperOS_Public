#!/bin/bash
# 解锁狂暴引擎（XML + vendor_dlkm + libmigui.so hexpatch）

mod_wildboost_engine() {
    echo -e "\n===== 解锁狂暴引擎 ====="

    local DEVICE_XML="$MIGRATION_EXTRACT_DIR/product/etc/device_features/${STOCK_EXTRACT_DIR##*/}.xml"
    local MAGISKBOOT="./tools/binary/magiskboot"
    local SYSTEM_EXT_PROP="$MIGRATION_EXTRACT_DIR/system_ext/etc/build.prop"

    # 1. XML 部分：添加 WildBoost 配置
    if [ -f "$DEVICE_XML" ]; then
        sed -i '/<!-- BSP BEGIN -->/a\
        <!-- Whether support WildBoost -->\
        <bool name="support_wild_boost">true</bool>\
        <!-- Whether support WildBoost in Battery & Performance -->\
        <bool name="support_wild_boost_bat_perf">true</bool>' "$DEVICE_XML"
        echo "  WildBoost XML 配置已添加"
    else
        warn_skip "$DEVICE_XML 不存在"
    fi

    # 2. vendor_dlkm：插入 perfmgr.ko 依赖
    local VENDOR_DLKM_MODULES="$STOCK_EXTRACT_DIR/vendor_dlkm/lib/modules"
    if [ -d "$VENDOR_DLKM_MODULES" ] && [ -f "./common_files/perfmgr.ko" ]; then
        cp -f ./common_files/perfmgr.ko "$VENDOR_DLKM_MODULES/"
        [ -f "$VENDOR_DLKM_MODULES/modules.dep" ] \
            && sed -i '/\/vendor\/lib\/modules\/msm_gpi\.ko:/a \/vendor\/lib\/modules\/perfmgr.ko:' "$VENDOR_DLKM_MODULES/modules.dep"
        [ -f "$VENDOR_DLKM_MODULES/modules.load" ] \
            && sed -i '/migt\.ko/a perfmgr.ko' "$VENDOR_DLKM_MODULES/modules.load"
        echo "  perfmgr.ko 已注入 vendor_dlkm"
    else
        [ ! -d "$VENDOR_DLKM_MODULES" ] && warn_skip "vendor_dlkm/lib/modules 不存在"
        [ ! -f "./common_files/perfmgr.ko" ] && warn_skip "perfmgr.ko 不存在"
    fi

    # 3. hexpatch libmigui.so（Eastmod device spoofing）
    if [ -f "$MAGISKBOOT" ]; then
        local TARGET_DIR="$MIGRATION_EXTRACT_DIR/system_ext"
        local LIB_FILES=("lib/libmigui.so" "lib64/libmigui.so")
        local REPLACEMENTS=(
            "726F2E70726F647563742E646576696365 726F2E656173746D6F642E646576696365"
            "726F2E70726F647563742E70726F647563742E6E616D65 726F2E656173746D6F642E70726F647563742E6E616D65"
        )
        for lib in "${LIB_FILES[@]}"; do
            local lib_path="${TARGET_DIR}/${lib}"
            [ ! -f "$lib_path" ] && { warn_skip "$lib_path 不存在"; continue; }
            for rule in "${REPLACEMENTS[@]}"; do
                local orig_hex=$(echo "$rule" | awk '{print $1}')
                local target_hex=$(echo "$rule" | awk '{print $2}')
                "$MAGISKBOOT" hexpatch "$lib_path" "$orig_hex" "$target_hex"
            done
        done
        echo "  libmigui.so hexpatch 完成"
    else
        warn_skip "magiskboot 不存在"
    fi

    # 添加 Eastmod 配置
    if [ -f "$SYSTEM_EXT_PROP" ]; then
        sed -i '$a \
# Eastmod FEAS Model \
ro.eastmod.device=vermeer \
ro.eastmod.product.name=vermeer' "$SYSTEM_EXT_PROP"
        echo "  Eastmod 配置已添加"
    fi

    # 复制 default_cloud.json
    if [ -f "./common_files/default_cloud.json" ]; then
        cp -f ./common_files/default_cloud.json "$STOCK_EXTRACT_DIR/odm/etc/"
        echo "  default_cloud.json 已复制"
    fi

    echo "  狂暴引擎处理完成"
}
