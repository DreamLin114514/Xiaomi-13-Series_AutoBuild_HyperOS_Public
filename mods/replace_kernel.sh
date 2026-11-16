#!/bin/bash
# 内核替换模块
# 用法：将自编译的 kernel Image 放到 ./kernel/Image
# 本模块会自动用 magiskboot 替换 boot.img 中的内核

KERNEL_IMAGE_PATH="./kernel/Image"

mod_replace_kernel() {
    echo -e "\n  [Kernel Replace] 检查自编译内核..."

    # 检查内核 Image 是否存在
    if [ ! -f "$KERNEL_IMAGE_PATH" ]; then
        echo -e "  [Kernel Replace] 未找到 $KERNEL_IMAGE_PATH，跳过内核替换"
        return 0
    fi

    echo -e "  [Kernel Replace] 找到自编译内核：$KERNEL_IMAGE_PATH"
    echo -e "  [Kernel Replace] 大小：$(du -h "$KERNEL_IMAGE_PATH" | awk '{print $1}')"

    # boot.img 路径（在 firmware 目录就绪后调用）
    local BOOT_IMG="./output/firmware/boot.img"
    if [ ! -f "$BOOT_IMG" ]; then
        echo -e "  [Kernel Replace] ⚠ $BOOT_IMG 不存在，跳过"
        return 0
    fi

    local ORIG_DIR="$(pwd)"
    local MAGISKBOOT="${ORIG_DIR}/tools/binary/magiskboot"
    local WORK_DIR="./kernel/_tmp_boot"

    # 清理并创建工作目录
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"

    # 复制 boot.img 到工作目录（不修改原始文件）
    cp "$BOOT_IMG" "$WORK_DIR/boot.img"
    cd "$WORK_DIR" || error_exit "无法进入工作目录 $WORK_DIR"

    echo -e "\n  [Kernel Replace] 解包 boot.img..."
    "$MAGISKBOOT" unpack boot.img || {
        cd - >/dev/null
        rm -rf "$WORK_DIR"
        error_exit "magiskboot unpack 失败"
    }

    # 检查解包结果
    if [ ! -f "kernel" ]; then
        cd - >/dev/null
        rm -rf "$WORK_DIR"
        error_exit "解包后未找到 kernel 文件，boot.img 格式可能不兼容"
    fi

    echo -e "  [Kernel Replace] 原始内核大小：$(du -h kernel | awk '{print $1}')"
    echo -e "  [Kernel Replace] 替换内核大小：$(du -h "../../$KERNEL_IMAGE_PATH" | awk '{print $1}')"

    # 替换内核
    cp -f "../../$KERNEL_IMAGE_PATH" kernel
    echo -e "  [Kernel Replace] 内核已替换"

    # 重新打包
    echo -e "\n  [Kernel Replace] 重新打包 boot.img..."
    "$MAGISKBOOT" repack boot.img || {
        cd - >/dev/null
        rm -rf "$WORK_DIR"
        error_exit "magiskboot repack 失败"
    }

    # 检查生成的新 boot.img
    if [ ! -f "new-boot.img" ]; then
        cd - >/dev/null
        rm -rf "$WORK_DIR"
        error_exit "magiskboot repack 未生成 new-boot.img"
    fi

    # 覆盖原始 boot.img
    cd - >/dev/null
    cp -f "$WORK_DIR/new-boot.img" "$BOOT_IMG"
    echo -e "  [Kernel Replace] ✅ boot.img 已更新"
    echo -e "  [Kernel Replace] 新 boot.img 大小：$(du -h "$BOOT_IMG" | awk '{print $1}')"

    # 清理工作目录
    rm -rf "$WORK_DIR"

    echo -e "\n  [Kernel Replace] 内核替换完成"
}
