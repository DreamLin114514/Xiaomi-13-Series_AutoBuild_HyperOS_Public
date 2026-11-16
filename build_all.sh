#!/bin/bash
# ======================== 多机型批量构建 ========================
# 交互式多选机型底包，一次跑完所有选中机型的构建。
#
# 固件包摆放：downloads/ 根目录或其子目录均可，自动扫描分类：
#   底包 Stock     —— 文件名含机型代号（ishtar / nuwa / fuxi）
#   移植包 Migration —— 文件名不含机型代号的 zip
#
# 构建流程：
#   1. 列出所有底包，多选（空格分隔，回车=全选）
#   2. 移植包：唯一时自动使用；有多个候选时选择一个（所有机型共用）
#   3. 版本号自动取「Migration 版本 + Stock 机型后缀」（解包后从 build.prop 计算），
#      需手动指定某机型版本号时填下方 VERSION_OVERRIDES
#   4. 逐机型调用 Build_local_HyperOS.sh（全部交互已预设，无需值守）
#
# 内核 / KSU init_boot：所有机型共用 kernel/Image 与 init_boot_ksu.img
#
# 用法：bash build_all.sh [打包模式]
#   全程交互：bash build_all.sh          → 依次交互选择 底包(多选)/移植包/打包模式
#   跳过交互：bash build_all.sh 1        → 直接指定打包模式
#   打包模式：1=常规 2=DSU 3=都要

cd "$(dirname "$0")" || exit 1

# 项目支持的机型代号（用于识别底包）
DEVICE_CODES=(ishtar nuwa fuxi)

# 可选：手动指定版本号（按机型代号，缺省自动取「Migration 版本 + Stock 机型后缀」）
declare -A VERSION_OVERRIDES=(
    # [ishtar]="OS3.0.319.0.WMACNXM"
    # [nuwa]="OS3.0.319.0.WMBCNXM"
    # [fuxi]="OS3.0.319.0.WOACNXM"
)

# ---- 扫描 downloads 下的固件包（含子目录） ----
all_zips=()
while IFS= read -r f; do
    all_zips+=("$f")
done < <(find ./downloads -maxdepth 2 -name "*.zip" -type f 2>/dev/null | sort)

[ ${#all_zips[@]} -eq 0 ] && { echo "错误：downloads/ 下没有 zip 固件包"; exit 1; }

# ---- 分类：底包（含机型代号）/ 移植包（其余） ----
stocks=()
migs=()
for f in "${all_zips[@]}"; do
    base=$(basename "$f")
    code=""
    for d in "${DEVICE_CODES[@]}"; do
        if [[ "$base" == *"$d"* ]]; then
            code="$d"
            break
        fi
    done
    if [ -n "$code" ]; then
        stocks+=("$code|$f")
    else
        migs+=("$f")
    fi
done

[ ${#stocks[@]} -eq 0 ] && { echo "错误：downloads/ 下未找到机型底包（文件名需含 ${DEVICE_CODES[*]}）"; exit 1; }

echo "========================================"
echo "  多机型批量构建"
echo "========================================"

# ---- 多选底包 ----
echo ""
echo "===== 选择要构建的机型底包（可多选） ====="
idx=0
for s in "${stocks[@]}"; do
    idx=$((idx + 1))
    echo "  $idx. [${s%%|*}] $(basename "${s#*|}")"
done
echo "  可多选，序号用空格或逗号分隔（如：1 3）；直接回车 = 全选"
read -p "请输入序号：" sel_input

selected=()
if [ -z "$sel_input" ]; then
    for i in $(seq 1 ${#stocks[@]}); do
        selected+=("$i")
    done
else
    for tok in ${sel_input//,/ }; do
        if ! [[ "$tok" =~ ^[0-9]+$ ]] || [ "$tok" -lt 1 ] || [ "$tok" -gt ${#stocks[@]} ]; then
            echo "错误：无效序号「$tok」，请重新运行"
            exit 1
        fi
        selected+=("$tok")
    done
fi

# 去重并保持选择顺序
declare -A _seen=()
ordered=()
for t in "${selected[@]}"; do
    [ -z "${_seen[$t]}" ] && { _seen[$t]=1; ordered+=("$t"); }
done
[ ${#ordered[@]} -eq 0 ] && { echo "错误：未选择任何底包"; exit 1; }

# ---- 选择移植包 ----
if [ ${#migs[@]} -eq 0 ]; then
    echo "错误：downloads/ 下未找到移植包（文件名不含机型代号的 zip）"
    exit 1
elif [ ${#migs[@]} -eq 1 ]; then
    mig_zip="${migs[0]}"
    echo ""
    echo "  移植包：$(basename "$mig_zip")"
else
    echo ""
    echo "===== 选择移植包（所有选中机型共用） ====="
    idx=0
    for m in "${migs[@]}"; do
        idx=$((idx + 1))
        echo "  $idx. $(basename "$m")"
    done
    read -p "请输入序号：" mig_sel
    if ! [[ "$mig_sel" =~ ^[0-9]+$ ]] || [ "$mig_sel" -lt 1 ] || [ "$mig_sel" -gt ${#migs[@]} ]; then
        echo "错误：无效序号「$mig_sel」，请重新运行"
        exit 1
    fi
    mig_zip="${migs[$((mig_sel - 1))]}"
fi

# ---- 打包模式 ----
if [ -n "$1" ]; then
    PACK_MODE="$1"
    echo "  打包模式（参数预设）：$PACK_MODE"
else
    echo ""
    echo "===== 选择打包模式 ====="
    echo "  1. 常规打包"
    echo "  2. DSU打包"
    echo "  3. 常规和DSU（生成两个包）"
    while true; do
        read -p "请输入选项序号（默认常规）：" PACK_MODE
        PACK_MODE="${PACK_MODE:-1}"
        [[ "$PACK_MODE" =~ ^[123]$ ]] && break
        echo "  无效选项，请输入 1/2/3"
    done
fi

# ---- 构建计划 ----
echo ""
echo "===== 构建计划 ====="
for t in "${ordered[@]}"; do
    entry="${stocks[$((t - 1))]}"
    echo "  [${entry%%|*}] $(basename "${entry#*|}")"
done
echo "  移植包：$(basename "$mig_zip")"
echo "  打包模式：$PACK_MODE"

# ---- 逐机型构建 ----
FAILED=()
DONE=()
for t in "${ordered[@]}"; do
    entry="${stocks[$((t - 1))]}"
    code="${entry%%|*}"
    stock_zip="${entry#*|}"

    echo ""
    echo "############################################"
    echo "# 机型：$code"
    echo "############################################"
    echo "  底包：$(basename "$stock_zip")"
    echo "  移植包：$(basename "$mig_zip")"

    new_version="${VERSION_OVERRIDES[$code]}"
    if [ -n "$new_version" ]; then
        echo "  版本号（手动指定）：$new_version"
    else
        echo "  版本号：自动（Migration 版本 + Stock 机型后缀）"
    fi

    build_ok=true
    if [ -n "$new_version" ]; then
        if STOCK_ZIP="$stock_zip" MIGRATION_ZIP="$mig_zip" NEW_VERSION="$new_version" \
           PACK_MODE="$PACK_MODE" \
           bash Build_local_HyperOS.sh; then
            DONE+=("$code")
        else
            build_ok=false
        fi
    else
        if STOCK_ZIP="$stock_zip" MIGRATION_ZIP="$mig_zip" AUTO_VERSION=1 \
           PACK_MODE="$PACK_MODE" \
           bash Build_local_HyperOS.sh; then
            DONE+=("$code")
        else
            build_ok=false
        fi
    fi
    if [ "$build_ok" = false ]; then
        echo "  !! $code 构建失败，继续下一个机型"
        FAILED+=("$code")
    fi
done

echo ""
echo "========================================"
echo "  批量构建结束"
echo "  成功：${DONE[*]:-无}"
echo "  失败/跳过：${FAILED[*]:-无}"
echo "  最新产物："
ls -1t ./zip/*.zip 2>/dev/null | head -10 | sed 's/^/    /'
echo "========================================"
