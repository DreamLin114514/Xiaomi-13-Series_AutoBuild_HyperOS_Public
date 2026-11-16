#!/bin/bash
# 添加狂暴引擎支持（vendor_boot）

mod_perfmgr_engine() {
    echo -e "\n===== 添加狂暴引擎支持（vendor_boot） ====="

    local VENDOR_BOOT="$STOCK_EXTRACT_DIR/vendor_boot.img"
    local PERFMGR="./common_files/perfmgr.ko"

    if [ ! -f "$VENDOR_BOOT" ]; then
        warn_skip "vendor_boot.img 不存在"
        return
    fi
    if [ ! -f "$PERFMGR" ]; then
        warn_skip "perfmgr.ko 不存在"
        return
    fi

    local WORK_DIR="./tmp_perfmgr"
    rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR"

    cp -f "$VENDOR_BOOT" "$WORK_DIR/"
    cp -f ./tools/binary/magiskboot "$WORK_DIR/"
    cp -f "$PERFMGR" "$WORK_DIR/"

    cd "$WORK_DIR"
    ./magiskboot unpack -h ./vendor_boot.img

    local COMP=$(./magiskboot decompress ramdisk.cpio 2>&1 | grep -v 'raw' | sed -n 's;.*\[\(.*\)\];\1;p')
    mv -f ramdisk.cpio "ramdisk.cpio.$COMP"
    ./magiskboot decompress "ramdisk.cpio.$COMP" ramdisk.cpio 2>&1
    mkdir -p ramdisk && chmod 755 ramdisk
    cd ramdisk
    EXTRACT_UNSAFE_SYMLINKS=1 cpio -d -F ../ramdisk.cpio -i 2>&1
    cd ..

    # 插入 perfmgr.ko
    mv -f ./perfmgr.ko ./ramdisk/lib/modules/

    # 插入 modules.dep
    sed -i '/\/lib\/modules\/msm_gpi.ko:/a \/lib\/modules\/perfmgr.ko: \/lib\/modules\/qcom-dcvs.ko \/lib\/modules\/dcvs_fp.ko \/lib\/modules\/qcom_rpmh.ko \/lib\/modules\/cmd-db.ko \/lib\/modules\/qcom_ipc_logging.ko \/lib\/modules\/minidump.ko \/lib\/modules\/smem.ko \/lib\/modules\/gh_rm_drv.ko \/lib\/modules\/gh_dbl.ko \/lib\/modules\/gh_msgq.ko \/lib\/modules\/gh_arm_drv.ko' ./ramdisk/lib/modules/modules.dep

    # 插入 modules.load.recovery
    sed -i '/migt\.ko/a perfmgr.ko' ./ramdisk/lib/modules/modules.load.recovery

    # 重新打包
    cd ./ramdisk
    find | sed 1d | cpio -H newc -R 0:0 -o -F ../ramdisk-new.cpio
    cd ..

    ./magiskboot compress=$comp ramdisk-new.cpio 2>&1
    if [ $? != 0 ] && $comp --help 2>/dev/null; then
        $comp -9c ramdisk-new.cpio > "ramdisk.cpio.$COMP"
    fi
    rm -rf ramdisk.cpio.lz4_legacy ramdisk.cpio

    local RAMDISK=$(ls ramdisk-new.cpio* 2>/dev/null | tail -n1)
    cp -f "$RAMDISK" ramdisk.cpio
    rm -rf ramdisk-new.cpio.lz4

    mkdir out
    ./magiskboot repack -n vendor_boot.img ./out/vendor_boot.img

    cd ..
    cp -f "./${WORK_DIR}/out/vendor_boot.img" "$VENDOR_BOOT"
    rm -rf "$WORK_DIR"
    echo "  狂暴引擎支持已添加"
}
