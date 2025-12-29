#!/bin/bash

# DeepCode 一键启动脚本
# 功能：检测环境、自动释放端口冲突、启动应用并打开网页

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# 端口配置
PORT=8503

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    DeepCode 一键启动脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 1. 检查Python环境
echo -e "${YELLOW}[1/5] 检查Python环境...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}错误: 未找到Python3，请先安装Python3${NC}"
    exit 1
fi
PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✓ Python环境正常: $PYTHON_VERSION${NC}"
echo ""

# 2. 检查虚拟环境
echo -e "${YELLOW}[2/5] 检查虚拟环境...${NC}"
if [ ! -d "venv" ] && [ ! -d ".venv" ]; then
    echo -e "${YELLOW}未找到虚拟环境，正在创建...${NC}"
    python3 -m venv venv
    echo -e "${GREEN}✓ 虚拟环境创建成功${NC}"
fi

# 激活虚拟环境
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d ".venv" ]; then
    source .venv/bin/activate
fi
echo -e "${GREEN}✓ 虚拟环境已激活${NC}"
echo ""

# 3. 检查依赖
echo -e "${YELLOW}[3/5] 检查依赖...${NC}"
if [ -f "requirements.txt" ]; then
    # 检查关键依赖是否已安装
    if ! python3 -c "import streamlit" 2>/dev/null; then
        echo -e "${YELLOW}正在安装依赖...${NC}"
        pip install -q -r requirements.txt
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ 依赖安装成功${NC}"
        else
            echo -e "${YELLOW}尝试使用uv安装依赖...${NC}"
            if command -v uv &> /dev/null; then
                uv pip install -r requirements.txt --system
            else
                echo -e "${RED}错误: 依赖安装失败${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${GREEN}✓ 依赖已安装${NC}"
    fi
else
    echo -e "${RED}错误: 未找到requirements.txt文件${NC}"
    exit 1
fi
echo ""

# 4. 检查并释放端口
echo -e "${YELLOW}[4/5] 检查端口 $PORT...${NC}"
PID=$(lsof -ti:$PORT 2>/dev/null)
if [ ! -z "$PID" ]; then
    echo -e "${YELLOW}端口 $PORT 被进程 $PID 占用，正在释放...${NC}"
    kill -9 $PID 2>/dev/null
    sleep 1
    # 再次检查
    PID=$(lsof -ti:$PORT 2>/dev/null)
    if [ -z "$PID" ]; then
        echo -e "${GREEN}✓ 端口 $PORT 已释放${NC}"
    else
        echo -e "${RED}错误: 无法释放端口 $PORT${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ 端口 $PORT 可用${NC}"
fi
echo ""

# 5. 启动应用
echo -e "${YELLOW}[5/5] 启动DeepCode应用...${NC}"
echo ""

# 后台启动streamlit应用
nohup streamlit run ui/streamlit_app.py --server.port=$PORT --server.headless=true > deepcode.log 2>&1 &
STREAMLIT_PID=$!

# 等待应用启动
echo -e "${YELLOW}等待应用启动...${NC}"
sleep 5

# 检查应用是否成功启动
if ps -p $STREAMLIT_PID > /dev/null; then
    echo -e "${GREEN}✓ DeepCode应用启动成功！${NC}"
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}    应用信息${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "本地地址: ${GREEN}http://localhost:$PORT${NC}"
    echo -e "网络地址: ${GREEN}http://$(hostname -I | awk '{print $1}'):$PORT${NC}"
    echo -e "进程ID: $STREAMLIT_PID"
    echo -e "日志文件: $PROJECT_DIR/deepcode.log"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    # 自动打开浏览器
    echo -e "${YELLOW}正在打开浏览器...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "http://localhost:$PORT"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "http://localhost:$PORT" 2>/dev/null || firefox "http://localhost:$PORT" 2>/dev/null
    fi
    echo -e "${GREEN}✓ 浏览器已打开${NC}"
    echo ""

    echo -e "${GREEN}应用正在后台运行...${NC}"
    echo -e "${YELLOW}提示: 使用以下命令查看日志${NC}"
    echo -e "  tail -f $PROJECT_DIR/deepcode.log"
    echo -e "${YELLOW}提示: 使用以下命令停止应用${NC}"
    echo -e "  kill $STREAMLIT_PID"
    echo ""
else
    echo -e "${RED}错误: 应用启动失败${NC}"
    echo -e "${YELLOW}查看日志: $PROJECT_DIR/deepcode.log${NC}"
    tail -20 deepcode.log
    exit 1
fi
