#!/bin/zsh

# vphone-cli 启动脚本
# 提供便捷的虚拟机启动和管理功能

set -euo pipefail

echo "=== vphone-cli 启动脚本 ==="

# 颜色定义
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

# 检查环境
check_environment() {
    echo "\n${YELLOW}检查环境...${NC}"
    
    # 检查 macOS 版本
    if [[ $(sw_vers -productVersion | cut -d. -f1) -lt 15 ]]; then
        echo "${RED}错误: 需要 macOS 15+ (Sequoia 或更高版本)${NC}"
        return 1
    fi
    
    # 检查 SIP 状态
    if [[ $(csrutil status | grep -o "status: .*" | cut -d' ' -f2) != "disabled" ]]; then
        echo "${RED}错误: SIP 必须禁用${NC}"
        echo "${YELLOW}请在 Recovery 模式下运行: csrutil disable${NC}"
        return 1
    fi
    
    # 检查 AMFI 设置
    if [[ -z $(nvram boot-args 2>/dev/null | grep "amfi_get_out_of_my_way=1") ]]; then
        echo "${RED}错误: AMFI 未禁用${NC}"
        echo "${YELLOW}请运行: sudo nvram boot-args=\"amfi_get_out_of_my_way=1 -v\" 并重启${NC}"
        return 1
    fi
    
    # 检查必要的依赖
    local missing=()
    for cmd in git-lfs wget gnu-tar ldid-procursus sshpass keystone; do
        if ! command -v $cmd &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "${RED}缺少依赖: ${missing[*]}${NC}"
        echo "${YELLOW}请运行: brew install ${missing[*]}${NC}"
        return 1
    fi
    
    # 检查构建状态
    if [[ ! -f ".build/release/vphone-cli" ]]; then
        echo "${YELLOW}构建文件不存在，开始构建...${NC}"
        make build
    fi
    
    echo "${GREEN}环境检查通过!${NC}"
    return 0
}

# 显示帮助信息
show_help() {
    echo "\n${YELLOW}使用方法:${NC}"
    echo "  ./launch.sh [命令] [选项]"
    echo "\n命令:"
    echo "  boot              - 启动虚拟机 (GUI 模式)"
    echo "  boot_dfu          - 启动虚拟机 (DFU 模式)"
    echo "  env               - 检查环境"
    echo "  setup             - 完整设置 (首次运行)"
    echo "  help              - 显示此帮助信息"
    echo "\n选项:"
    echo "  --vm-dir <目录>    - 指定虚拟机目录 (默认: vm)"
    echo "  --cpu <数量>       - CPU 核心数 (默认: 8)"
    echo "  --memory <MB>      - 内存大小 (默认: 8192)"
}

# 完整设置
full_setup() {
    echo "\n${YELLOW}开始完整设置...${NC}"
    
    # 安装依赖
    echo "${YELLOW}1. 安装工具...${NC}"
    make setup_tools
    
    # 激活虚拟环境
    echo "${YELLOW}2. 激活虚拟环境...${NC}"
    source .venv/bin/activate
    
    # 创建虚拟机目录
    echo "${YELLOW}3. 创建虚拟机目录...${NC}"
    make vm_new
    
    # 准备固件
    echo "${YELLOW}4. 准备固件...${NC}"
    make fw_prepare
    
    # 打补丁
    echo "${YELLOW}5. 打补丁...${NC}"
    make fw_patch
    
    echo "\n${GREEN}完整设置完成!${NC}"
    echo "${YELLOW}下一步: ./launch.sh boot_dfu 启动 DFU 模式${NC}"
}

# 主函数
main() {
    local cmd="help"
    local vm_dir="vm"
    local cpu="8"
    local memory="8192"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            boot|boot_dfu|env|setup|help)
                cmd="$1"
                ;;
            --vm-dir)
                vm_dir="$2"
                shift
                ;;
            --cpu)
                cpu="$2"
                shift
                ;;
            --memory)
                memory="$2"
                shift
                ;;
            *)
                echo "${RED}未知参数: $1${NC}"
                show_help
                return 1
                ;;
        esac
        shift
    done
    
    case $cmd in
        env)
            check_environment
            ;;
        setup)
            check_environment && full_setup
            ;;
        boot)
            check_environment && make boot VM_DIR="$vm_dir" CPU="$cpu" MEMORY="$memory"
            ;;
        boot_dfu)
            check_environment && make boot_dfu VM_DIR="$vm_dir" CPU="$cpu" MEMORY="$memory"
            ;;
        help)
            show_help
            ;;
        *)
            show_help
            ;;
    esac
}

# 执行主函数
main "$@"
