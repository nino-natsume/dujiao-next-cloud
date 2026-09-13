FROM dujiaonext/dujiao-next:v1.4.7

# 容器内需要 redis（队列/缓存）和 supervisor（托管两个进程）
USER root
RUN apk add --no-cache redis supervisor

# 烧入配置（含密钥！本目录务必推送到【私有】仓库）
COPY config.yml /app/config.yml
COPY supervisord.conf /etc/supervisord.conf

# 数据目录可写（uploads 免费层重启会丢，备胎保存商品图）
RUN mkdir -p /app/db /app/uploads /app/logs /data && chmod -R 777 /app /data

EXPOSE 8080

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]