# Dujiao-Next 全栈镜像（dujiaonext/dujiao-next）· Render Free + Supabase 部署
# 用法：push 到 GitHub 私有仓库，Render 自动构建
# =============================================================================
FROM dujiaonext/dujiao-next:v1.4.7

# 容器内需要 redis（队列/缓存）；不再用 supervisor，改用 entrypoint.sh
USER root
RUN apk add --no-cache redis && mkdir -p /app/uploads /app/logs /data && chmod -R 777 /app /data

# 烧入配置（含密钥！本目录务必推送到【私有】仓库）
COPY config.yml /app/config.yml
COPY entrypoint.sh /app/entrypoint.sh
# 防 Windows CRLF 行尾把 shell 脚本搞坏，顺便加执行权限
RUN sed -i 's/\r$//' /app/entrypoint.sh && chmod +x /app/entrypoint.sh

EXPOSE 8080

CMD ["/bin/sh", "/app/entrypoint.sh"]