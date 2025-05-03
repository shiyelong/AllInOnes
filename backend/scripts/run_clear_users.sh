#!/bin/bash

# 确保在backend目录下运行
cd "$(dirname "$0")/.."

echo "正在编译清除用户数据脚本..."
go run scripts/clear_users.go

echo "脚本执行完成"
