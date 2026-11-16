#!/bin/bash
# patchmethod - 替换 smali 方法体
# 用法: patchmethod <file> <method_name> -return <value>
# 示例: patchmethod Foo.smali canJoinSharedUserId -return true

FILE="$1"
METHOD="$2"
SHIFT="$3"
VALUE="$4"

if [ "$SHIFT" = "-return" ]; then
    if [ "$VALUE" = "true" ]; then
        REPLACE='.registers 4\n\n    const/4 p0, 0x1\n\n    return p0'
    elif [ "$VALUE" = "false" ]; then
        REPLACE='.registers 4\n\n    const/4 p0, 0x0\n\n    return p0'
    elif [ "$VALUE" = "0" ]; then
        REPLACE='.registers 4\n\n    const/4 p0, 0x0\n\n    return p0'
    fi
fi

sed -i "/\.method.*${METHOD}/,/\.end method/{
    /\.method/!{/\.end method/!d}
    /\.method/{
        a\\
${REPLACE}
    }
}" "$FILE"
