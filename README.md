# [Dujiao-Next](https://dujiao-next.com) 免服务器·云 Docker & Postgresql 部署

本方案非官方，项目仍有不足，仅提供部署方法，将不再维护

## 目录

- [准备](#准备)
- [需修改的配置](#需修改的配置)
- [为什么使用这些？](#为什么使用这些)
- [架构总览](#架构总览)
- [步骤](#步骤)
- [升级与回滚](#升级与回滚)
- [可能出现的问题及解决方法](#可能出现的问题及解决方法)
- [安全须知](#安全须知)
- [参考](#参考)

---

## 准备

以下部分可替代，本篇以以下内容为主编写，自行注册和登录，该部分不再赘述

- [Supabase](https://supabase.com) 账号（可使用其他云数据库，本篇以此为例）
- [Render](https://render.com) 账号
- 已托管的域名一个
- [Render](https://render.com) 账号（非必须，只要能连上smtp就行）
- [UptimeRobot](https://uptimerobot.com) 账号

## 需修改的配置

| 占位符 | 含义 | 去哪拿 |
|---|---|---|
| `<APP_SECRET_KEY>` `<JWT_SECRET>` `<USER_JWT_SECRET>` | 三个互不相同的 64 位随机密钥 | 本地生成，见下 |
| `<SUPABASE_PROJECT_REF>` | Supabase 项目 ref | Supabase → Settings → Database |
| `<SUPABASE_DB_PASSWORD>` | Supabase 数据库密码 | 建项目时设置；有特殊字符需 URL 编码 |
| `<SUPABASE_REGION>` | Supabase 区域（如 `ap-northeast-1`） | Supabase 项目设置 |
| `<ADMIN_USERNAME>` `<ADMIN_PASSWORD>` | 初始管理员 | 自定（强密码！登录后立刻改） |
| `<RESEND_API_KEY>` | Resend API Key（`re_xxx`） | resend.com → API Keys |
| `<YOUR_DOMAIN>` | 已验证的发件域名 | resend.com → Domains（需 DNS 验证） |
| `<发件邮箱>` `<你的站点名>` | 发件邮箱与显示名 | 自定（`@<YOUR_DOMAIN>` 下） |
| `<ADMIN_PATH>` | 后台路径（别用 `/admin`） | 自定，如 `admin-abc123` |

上面三个值的密钥怎么生成？
win:
```
$b = New-Object byte[] 32; [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); (-join ($b | ForEach-Object { $_.ToString('x2') }))
```

其他：
```
sudo apt install openssl
openssl rand -hex
```

## 为什么使用这些？

众所周知，服务器贵，甲骨文云难注册，本地难持久运行，部分云服务器仅试用，部分服务商有额度

故，采取稍麻烦点的方案，即：Supabase + Github + Render + UptimeRobot

但，Github 保存代码，Supabase 当数据库，Render 运行 Docker ，UptimeRobot 维持容器持续稳定，顺便监控网站是否正常运行，一个周期下来能完整实现持续运行、永久免费

## 架构总览

```
浏览器 / 顾客
      │
      ▼
Render Free Web Service ── HTTPS ── https://xxx.example.com
      │  （entrypoint.sh：redis 后台 &，dujiao 前台 exec）
      ├─ redis-server                 (127.0.0.1:6379，缓存/队列，重启丢数据没关系)
      └─ dujiao-next                  (监听 :8080，连 Supabase Postgres)
              │                                       │
              ▼                                       ▼
     SMTP(发卡密/通知，可能不可用)     Supabase Postgres(免费 500MB，永久)
```

- 商品卡密、订单、用户、后台设置 → **Supabase Postgres**（永久保留）
- 队列/缓存/限流 → 容器内 **Redis**（临时数据）
- 发卡密/通知邮件 → **Resend**
- 上传的商品图片 → 容器本地盘（免费层重启会丢）→ 建议图床外链

## 步骤

1. Fork 本仓库，修改 `config.yml` 内的内容，注意部署前检查和连通性测试；当前方案的邮件配置可能有问题，不需要用的话尽量不要配置

2. 进入 Render，选择 github ，选择 Create New Web Service，选择 Github，选择仓库，检查以下内容：

| Runtime | Docker |
| --- | --- |
| Instance | Free |
| Health Check | /health |

3. 进入 UptimeRobot，添加一个监控项 `https://xxx.xample.com/health`

4. 进入 Supabase，创建项目，在项目主页复制形如 `postgresql://postgres:[YOUR-PASSWORD]@db.fiiaepoffjqtfqpwexqh.supabase.co:5432/postgres` 的链接

5. 将链接修改为 `postgresql://postgres.<Project ID>:<SUPABASE_DB_PASSWORD>@aws-0-<Project region>.pooler.supabase.com:5432/postgres?sslmode=require`，Project region 和 Project ID 在 Setting 里找

6. 返回 Render，等待部署完成，部署时会自动创建数据表，无需另操作，期间可配置自定义域，上方数据库地址需正确，否则部署失败

## 升级与回滚

- 升级：改 `Dockerfile` 的镜像 tag（如 `v1.4.8`）→ push → 自动重建
- 回滚：Render → Deploys → 选历史部署 → **Rollback**

## 可能出现的问题及解决方法

| 现象 | 原因 / 解决 |
|---|---|
| dujiao exit 1，Render 报无端口 | DSN 用了 `db.xxx.supabase.co` 直连（免费档 IPv6-only）→ 改 pooler 5432 |
| 连库报 prepared statement 错误 | 用了 6543 事务池 → 改 session pooler 5432 |
| supervisor 崩 `Invalid seek` | 日志写 `/dev/stdout` → 换 entrypoint.sh 方案 |
| 邮件"无法连接 SMTP" | 字段写错：官方是 `use_ssl`/`use_tls`，不是 `smtp_tls`；`from`/`from_name` 分开 |
| 邮件"网络连接失败" | 端口与协议不配对：465=SSL，587=STARTTLS（`use_tls: true`），若尝试无果则放弃配置 |
| 发信报域名未验证 | Resend 域名未 Active；`from` 必须用已验证域名 |
| 商品图重启后消失 | 免费层容器盘临时 → 图床外链 |
| Supabase 被暂停 | 免费档 1 周无活动 → 保活可避免；万一暂停 Dashboard Restore |
| 后台 404 | `web.admin_path` 与 URL 不一致 → 改配置重新部署 |
| 内存被打满被杀 | 调小队列并发、`mode: release` |

## 安全须知

- 仓库**必须 Private**；公开过的密钥一律轮换
- `app.secret_key`/JWT 密钥泄露 = 订单数据裸奔；丢失 = 数据永久无法恢复
- 管理员初始密码登录后**立即更换**
- 后台路径不要用 `/admin`
- 发卡/数字商品站点请确保内容与运营**合法合规**

## 参考

- Dujiao-Next 官方文档：https://dujiao-next.com/deploy/docker-compose
- Dujiao-Next GitHub：https://github.com/dujiao-next/dujiao-next
- Supabase 连接指南：https://supabase.com/docs/guides/database/connecting-to-postgres
- Resend API 文档：https://resend.com/docs/api-reference
- Render Web Services：https://render.com/docs/web-services
