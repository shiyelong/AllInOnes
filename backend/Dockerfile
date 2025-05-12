FROM golang:1.20-alpine AS builder

# 设置工作目录
WORKDIR /app

# 安装必要的工具
RUN apk add --no-cache git gcc musl-dev

# 复制go.mod和go.sum文件
COPY go.mod go.sum ./

# 下载依赖
RUN go mod download

# 复制源代码
COPY . .

# 编译应用
RUN CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo -o allinone-backend ./cmd/main.go

# 使用更小的基础镜像
FROM alpine:latest

# 安装必要的运行时依赖
RUN apk --no-cache add ca-certificates tzdata sqlite

# 设置时区
ENV TZ=Asia/Shanghai

# 创建非root用户
RUN adduser -D -g '' appuser

# 创建必要的目录
RUN mkdir -p /app/uploads /app/data /app/logs
RUN chown -R appuser:appuser /app

# 设置工作目录
WORKDIR /app

# 从builder阶段复制编译好的应用
COPY --from=builder /app/allinone-backend .

# 复制配置文件和静态资源
COPY --from=builder /app/config ./config
COPY --from=builder /app/static ./static

# 设置权限
RUN chmod +x /app/allinone-backend
RUN chown -R appuser:appuser /app

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 3001

# 设置健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3001/api/health || exit 1

# 启动应用
CMD ["/app/allinone-backend"]
