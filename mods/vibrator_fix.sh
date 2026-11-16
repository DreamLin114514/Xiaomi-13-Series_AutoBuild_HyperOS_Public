#!/bin/bash
# 修复震动（合入自上游 7517cb3：FixVibrator alias 服务方案）
# 旧方案（hexpatch HAL 实例名 + miui-services smali 改写）已废弃：
# alias 服务以 IVibrator/default 注册并转发到 vibratorfeature HAL，framework 无需改动

mod_vibrator_fix() {
    echo -e "\n===== 修复震动 ====="
    local VIBRATOR_SRC="./common_files/FixVibrator"
    # .rc 内服务路径固定为 /odm/bin/hw，因此 alias 装进 odm 分区
    local VIBRATOR_MANIFEST="$STOCK_EXTRACT_DIR/odm/etc/vintf/manifest/vendor.xiaomi.hardware.vibratorfeature.service.xml"
    local ODM_FS_CONFIG="$STOCK_EXTRACT_DIR/config/odm_fs_config"
    local ODM_FILE_CONTEXTS="$STOCK_EXTRACT_DIR/config/odm_file_contexts"

    if [ -f "$VIBRATOR_SRC/vendor.vibrator-default-alias" ] && [ -f "$VIBRATOR_SRC/vendor.vibrator-default-alias.rc" ]; then
        # 允许 hal_vibrator_default 对自身域发起 binder 调用（odm 策略是 vendor sepolicy 的扩展，规则写 vendor cil）
        local VENDOR_SEPOLICY_CIL="$STOCK_EXTRACT_DIR/vendor/etc/selinux/vendor_sepolicy.cil"
        if [ -f "$VENDOR_SEPOLICY_CIL" ]; then
            echo "(allow hal_vibrator_default hal_vibrator_default (binder (call transfer)))" >> "$VENDOR_SEPOLICY_CIL"
        else
            warn_skip "$VENDOR_SEPOLICY_CIL 不存在"
        fi
        # 策略已更新，删除 vendor/odm 预编译 sepolicy
        find "$STOCK_EXTRACT_DIR/vendor" "$STOCK_EXTRACT_DIR/odm" -type f -name "*precompiled_sepolicy*" -delete
        # 复制 alias 服务文件（用 cp 保留 common_files 原件，便于重复打包）
        mkdir -p "$STOCK_EXTRACT_DIR/odm/bin/hw" "$STOCK_EXTRACT_DIR/odm/etc/init"
        cp -f "$VIBRATOR_SRC/vendor.vibrator-default-alias" "$STOCK_EXTRACT_DIR/odm/bin/hw/"
        cp -f "$VIBRATOR_SRC/vendor.vibrator-default-alias.rc" "$STOCK_EXTRACT_DIR/odm/etc/init/"
        # 在 vibratorfeature 服务的 VINTF 清单中追加 default 实例
        if [ -f "$VIBRATOR_MANIFEST" ]; then
            sed -Ei '/<fqname>[[:space:]]*IVibrator\/vibratorfeature[[:space:]]*<\/fqname>/a\        <fqname>IVibrator/default</fqname>' "$VIBRATOR_MANIFEST"
        else
            warn_skip "$VIBRATOR_MANIFEST 不存在"
        fi
        # 注册 fs_config 权限与 SELinux 上下文
        if [ -f "$ODM_FS_CONFIG" ] && [ -f "$ODM_FILE_CONTEXTS" ]; then
            echo "odm/bin/hw/vendor.vibrator-default-alias 0 2000 0755" >> "$ODM_FS_CONFIG"
            echo "/odm/bin/hw/vendor\.vibrator-default-alias u:object_r:hal_vibrator_default_exec:s0" >> "$ODM_FILE_CONTEXTS"
            echo "odm/etc/init/vendor.vibrator-default-alias.rc 0 0 0644" >> "$ODM_FS_CONFIG"
            echo "/odm/etc/init/vendor\.vibrator-default-alias\.rc u:object_r:vendor_configs_file:s0" >> "$ODM_FILE_CONTEXTS"
        else
            warn_skip "config 下缺少 odm_fs_config / odm_file_contexts"
        fi
        echo "  震动修复完成"
    else
        warn_skip "$VIBRATOR_SRC 下缺少 alias 文件"
    fi
}
