#!/usr/bin/env bash
# stm32.sh — STM32CubeIDE Makefile 專案的 build/flash 助手
#
# 用法:
#   stm32.sh build               # 只編譯
#   stm32.sh flash [file]        # 只燒錄（file 可省略，自動找 Debug/<name>.hex）
#   stm32.sh build-flash [file]  # 編譯後燒錄
#   stm32.sh clean               # 清除編譯產物
#
# 參數:
#   --project-dir <path>   Makefile 所在目錄（預設 .）
#   --build-dir <name>     輸出目錄名（預設 Debug）
#   --jobs <N>             make -j N（預設 CPU 核心數）
#   --format hex|elf|bin   燒錄格式（預設 hex）
#   --address <hex>        .bin 燒錄起始位址（預設 0x08000000）
#   --verbose              顯示完整指令與輸出
#
# Exit codes:
#   0 成功 / 1 編譯失敗 / 2 燒錄失敗 / 3 工具找不到 / 4 檔案找不到 / 5 參數錯誤

set -o pipefail

# ---------- 預設值 ----------
PROJECT_DIR="."
BUILD_DIR="Debug"
JOBS=""
FORMAT="hex"
ADDRESS="0x08000000"
VERBOSE=0
COMMAND=""
FLASH_FILE=""

# ---------- 顏色（若 stdout 是 tty 才用）----------
if [ -t 1 ]; then
    C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_WARN=$'\033[33m'
    C_INFO=$'\033[36m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
    C_OK=""; C_ERR=""; C_WARN=""; C_INFO=""; C_DIM=""; C_RESET=""
fi

log_info()  { echo "${C_INFO}[INFO]${C_RESET} $*"; }
log_ok()    { echo "${C_OK}[OK]${C_RESET} $*"; }
log_warn()  { echo "${C_WARN}[WARN]${C_RESET} $*" >&2; }
log_err()   { echo "${C_ERR}[ERROR]${C_RESET} $*" >&2; }
log_debug() { [ "$VERBOSE" = "1" ] && echo "${C_DIM}[DEBUG]${C_RESET} $*" >&2; }

# ---------- 路徑轉換（WSL / Git Bash 友善）----------
# 有些 Windows 工具（例如 STM32_Programmer_CLI.exe）不吃 /mnt/c/... 或 /c/... 路徑
# 這時要轉成 C:\... 形式
to_native_path() {
    local p="$1"
    # 絕對路徑才處理
    case "$p" in
        /mnt/[a-z]/*)  # WSL
            if command -v wslpath >/dev/null 2>&1; then
                wslpath -w "$p"
            else
                echo "$p"
            fi
            ;;
        /[a-z]/*)  # Git Bash 的 MSYS 風格
            if command -v cygpath >/dev/null 2>&1; then
                cygpath -w "$p"
            else
                echo "$p"
            fi
            ;;
        *)
            echo "$p"
            ;;
    esac
}

# ---------- 工具偵測 ----------
# 依序檢查：PATH → WSL mount 下的 Windows 常見位置 → Linux 常見位置
# 找到後 echo 路徑；找不到 return 1
find_tool() {
    local tool_name="$1"
    shift
    local fallback_paths=("$@")

    # 1) PATH
    if command -v "$tool_name" >/dev/null 2>&1; then
        command -v "$tool_name"
        return 0
    fi

    # 2) fallback globs
    local pattern
    for pattern in "${fallback_paths[@]}"; do
        # 用 shell glob 展開（可能是 /mnt/c/ST/STM32CubeIDE_*/.../arm-none-eabi-gcc.exe）
        local matches=( $pattern )
        local candidate
        for candidate in "${matches[@]}"; do
            if [ -x "$candidate" ] || [ -f "$candidate" ]; then
                echo "$candidate"
                return 0
            fi
        done
    done

    return 1
}

# make 的預設位置候選
MAKE_CANDIDATES=(
    "/mnt/c/ST/STM32CubeIDE_*/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.make.*/tools/bin/make.exe"
    "/c/ST/STM32CubeIDE_*/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.make.*/tools/bin/make.exe"
    "/mnt/c/Program Files/GnuWin32/bin/make.exe"
    "/usr/bin/make"
)

# arm-none-eabi-gcc 候選（主要看 STM32CubeIDE 內建的 GNU Tools）
GCC_CANDIDATES=(
    "/mnt/c/ST/STM32CubeIDE_*/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.*/tools/bin/arm-none-eabi-gcc.exe"
    "/c/ST/STM32CubeIDE_*/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.*/tools/bin/arm-none-eabi-gcc.exe"
    "/mnt/c/Program Files/GNU Arm Embedded Toolchain/*/bin/arm-none-eabi-gcc.exe"
    "/usr/bin/arm-none-eabi-gcc"
)

# STM32_Programmer_CLI 候選
CLI_CANDIDATES=(
    "/mnt/c/Program Files/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe"
    "/c/Program Files/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI.exe"
    "/mnt/c/ST/STM32CubeIDE_*/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.*/tools/bin/STM32_Programmer_CLI.exe"
    "/c/ST/STM32CubeIDE_*/STM32CubeIDE/plugins/com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.*/tools/bin/STM32_Programmer_CLI.exe"
)

resolve_tools() {
    MAKE_BIN=$(find_tool "make" "${MAKE_CANDIDATES[@]}") || {
        log_err "找不到 make。請安裝 make 或把 STM32CubeIDE 的 make 加入 PATH。"
        exit 3
    }
    log_debug "make: $MAKE_BIN"

    # gcc 只是做存在性檢查（實際呼叫由 Makefile 負責）
    GCC_BIN=$(find_tool "arm-none-eabi-gcc" "${GCC_CANDIDATES[@]}") || {
        log_warn "PATH 中找不到 arm-none-eabi-gcc；若 Makefile 內已指定絕對路徑可忽略此警告。"
        GCC_BIN=""
    }
    [ -n "$GCC_BIN" ] && log_debug "arm-none-eabi-gcc: $GCC_BIN"

    if [ "$COMMAND" = "flash" ] || [ "$COMMAND" = "build-flash" ]; then
        CLI_BIN=$(find_tool "STM32_Programmer_CLI" "${CLI_CANDIDATES[@]}") || {
            log_err "找不到 STM32_Programmer_CLI。請安裝 STM32CubeProgrammer 或將其 bin/ 加入 PATH。"
            exit 3
        }
        log_debug "STM32_Programmer_CLI: $CLI_BIN"
    fi
}

# ---------- 子命令：build ----------
do_build() {
    cd "$PROJECT_DIR" || { log_err "專案目錄不存在：$PROJECT_DIR"; exit 4; }

    if [ ! -f "Makefile" ] && [ ! -f "makefile" ]; then
        log_err "在 $PROJECT_DIR 找不到 Makefile。STM32CubeIDE 的 Makefile 通常在 Debug/ 或 Release/ 裡面。"
        log_err "請用 --project-dir 指向含 Makefile 的目錄（例如 your_project/Debug）。"
        exit 4
    fi

    local jobs_flag=""
    if [ -n "$JOBS" ]; then
        jobs_flag="-j$JOBS"
    else
        # 自動偵測核心數
        local nproc_val
        nproc_val=$(nproc 2>/dev/null || echo "")
        [ -n "$nproc_val" ] && jobs_flag="-j$nproc_val"
    fi

    log_info "編譯中：$MAKE_BIN $jobs_flag all"
    log_info "工作目錄：$(pwd)"

    if [ "$VERBOSE" = "1" ]; then
        "$MAKE_BIN" $jobs_flag all
    else
        "$MAKE_BIN" $jobs_flag all 2>&1 | tail -20
    fi
    local rc=${PIPESTATUS[0]}

    if [ "$rc" -ne 0 ]; then
        log_err "編譯失敗 (exit=$rc)"
        exit 1
    fi

    # 找產出的 .elf，推斷 basename
    local elf_file
    elf_file=$(ls -1 *.elf 2>/dev/null | head -1)
    if [ -z "$elf_file" ]; then
        log_warn "找不到 .elf 檔案，無法產生 .bin/.hex"
        return
    fi

    local base="${elf_file%.elf}"
    local bin_file="${base}.bin"
    local hex_file="${base}.hex"

    # 若 Makefile 沒有自動產 .bin 或 .hex，手動補做
    # 先找 objcopy：優先用和 gcc 同目錄的
    local objcopy_bin=""
    if [ -n "$GCC_BIN" ]; then
        objcopy_bin="${GCC_BIN%/*}/arm-none-eabi-objcopy"
        [ -f "${objcopy_bin}.exe" ] && objcopy_bin="${objcopy_bin}.exe"
        [ -x "$objcopy_bin" ] || [ -f "$objcopy_bin" ] || objcopy_bin=""
    fi
    [ -z "$objcopy_bin" ] && objcopy_bin=$(command -v arm-none-eabi-objcopy 2>/dev/null || echo "")

    if [ ! -f "$bin_file" ]; then
        if [ -n "$objcopy_bin" ]; then
            log_info "Makefile 未產 .bin，手動執行 objcopy..."
            "$objcopy_bin" -O binary "$elf_file" "$bin_file" || log_warn ".bin 產生失敗"
        else
            log_warn "找不到 arm-none-eabi-objcopy，跳過 .bin 生成"
        fi
    fi

    if [ ! -f "$hex_file" ]; then
        if [ -n "$objcopy_bin" ]; then
            log_info "Makefile 未產 .hex，手動執行 objcopy..."
            "$objcopy_bin" -O ihex "$elf_file" "$hex_file" || log_warn ".hex 產生失敗"
        else
            log_warn "找不到 arm-none-eabi-objcopy，跳過 .hex 生成"
        fi
    fi

    # 報告結果
    echo
    log_ok "編譯成功"
    echo "產生檔案："
    for f in "$elf_file" "$bin_file" "$hex_file"; do
        if [ -f "$f" ]; then
            local size
            size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo "?")
            printf "  %-40s  %s bytes\n" "$(pwd)/$f" "$size"
        fi
    done

    # 把 elf 路徑存起來給 build-flash 用
    LAST_BUILD_DIR=$(pwd)
    LAST_ELF="$elf_file"
    LAST_BIN="$bin_file"
    LAST_HEX="$hex_file"
}

# ---------- 子命令：flash ----------
do_flash() {
    local target_file="$1"

    # 若沒指定檔案，根據 FORMAT 自動挑
    if [ -z "$target_file" ]; then
        cd "$PROJECT_DIR" || { log_err "專案目錄不存在：$PROJECT_DIR"; exit 4; }
        local ext
        case "$FORMAT" in
            hex) ext="hex" ;;
            elf) ext="elf" ;;
            bin) ext="bin" ;;
            *)   log_err "未知格式：$FORMAT（只支援 hex/elf/bin）"; exit 5 ;;
        esac
        target_file=$(ls -1 *.$ext 2>/dev/null | head -1)
        if [ -z "$target_file" ]; then
            log_err "在 $(pwd) 找不到 .$ext 檔案。先跑 build，或用 stm32.sh flash <路徑> 指定。"
            exit 4
        fi
        target_file="$(pwd)/$target_file"
    fi

    if [ ! -f "$target_file" ]; then
        log_err "燒錄檔案不存在：$target_file"
        exit 4
    fi

    # 根據副檔名決定格式（使用者明確給檔案時以副檔名為準）
    local ext="${target_file##*.}"
    ext="${ext,,}"  # 轉小寫

    local native_path
    native_path=$(to_native_path "$target_file")
    log_debug "native path: $native_path"

    log_info "燒錄：$target_file"
    log_info "格式：.$ext"

    local cli_args=(-c port=SWD -w "$native_path")
    if [ "$ext" = "bin" ]; then
        cli_args+=("$ADDRESS")
        log_info "起始位址：$ADDRESS"
    fi
    cli_args+=(-v -rst)

    log_debug "呼叫：$CLI_BIN ${cli_args[*]}"

    if [ "$VERBOSE" = "1" ]; then
        "$CLI_BIN" "${cli_args[@]}"
    else
        # 非 verbose 時過濾掉大量進度條，只保留關鍵行
        "$CLI_BIN" "${cli_args[@]}" 2>&1 | grep -E -i 'error|warning|success|download|verify|reset|^ST-LINK|Chip ID|Device name|bytes' || true
        # 但仍要抓真正的 exit code
    fi
    local rc=${PIPESTATUS[0]}

    if [ "$rc" -ne 0 ]; then
        log_err "燒錄失敗 (exit=$rc)"
        exit 2
    fi

    log_ok "燒錄成功並重置"
}

# ---------- 子命令：clean ----------
do_clean() {
    cd "$PROJECT_DIR" || { log_err "專案目錄不存在：$PROJECT_DIR"; exit 4; }
    if [ -f "Makefile" ] || [ -f "makefile" ]; then
        log_info "執行：$MAKE_BIN clean"
        "$MAKE_BIN" clean
        log_ok "Clean 完成"
    else
        log_err "找不到 Makefile"
        exit 4
    fi
}

# ---------- 參數解析 ----------
usage() {
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
}

if [ $# -eq 0 ]; then
    usage
    exit 5
fi

COMMAND="$1"
shift

# 若第一個位置參數不是 flag，視為 flash 目標檔
if [ "$COMMAND" = "flash" ] || [ "$COMMAND" = "build-flash" ]; then
    if [ $# -gt 0 ] && [ "${1:0:2}" != "--" ]; then
        FLASH_FILE="$1"
        shift
    fi
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --project-dir) PROJECT_DIR="$2"; shift 2 ;;
        --build-dir)   BUILD_DIR="$2"; shift 2 ;;
        --jobs)        JOBS="$2"; shift 2 ;;
        --format)      FORMAT="$2"; shift 2 ;;
        --address)     ADDRESS="$2"; shift 2 ;;
        --verbose|-v)  VERBOSE=1; shift ;;
        --help|-h)     usage; exit 0 ;;
        *)             log_err "未知參數：$1"; usage; exit 5 ;;
    esac
done

# ---------- Dispatch ----------
# 先驗證 command 合法，再去找工具（避免打錯指令還浪費時間掃目錄）
case "$COMMAND" in
    build|flash|build-flash|clean) ;;
    *)
        log_err "未知指令：$COMMAND"
        usage
        exit 5
        ;;
esac

resolve_tools

case "$COMMAND" in
    build)
        do_build
        ;;
    flash)
        # 若使用者給相對路徑，在當前目錄先解析
        if [ -n "$FLASH_FILE" ] && [ "${FLASH_FILE:0:1}" != "/" ]; then
            FLASH_FILE="$(pwd)/$FLASH_FILE"
        fi
        do_flash "$FLASH_FILE"
        ;;
    build-flash)
        do_build
        # build 完後，根據 FORMAT 挑檔燒錄
        cd "$LAST_BUILD_DIR"
        flash_target=""
        case "$FORMAT" in
            hex) flash_target="$LAST_HEX" ;;
            elf) flash_target="$LAST_ELF" ;;
            bin) flash_target="$LAST_BIN" ;;
        esac
        if [ -n "$FLASH_FILE" ]; then
            [ "${FLASH_FILE:0:1}" != "/" ] && FLASH_FILE="$LAST_BUILD_DIR/$FLASH_FILE"
            flash_target="$FLASH_FILE"
        fi
        if [ ! -f "$flash_target" ]; then
            log_err "build 成功但找不到 $flash_target 可燒錄"
            exit 4
        fi
        echo
        do_flash "$LAST_BUILD_DIR/$(basename "$flash_target")"
        ;;
    clean)
        do_clean
        ;;
esac
