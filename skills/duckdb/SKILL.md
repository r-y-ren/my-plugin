---
name: duckdb
description: 本地大表 SQL 分析（单二进制免服务免装环境）——对 CSV/Parquet/JSON 文件直接跑 SQL：计数/分组/join/去重/抽样/清洗导出，毫秒级出结果。何时用：数千行以上数据文件摸底统计、跨格式关联查询，把"整读大文件灌上下文"降为"聚合后看几行"。
---

# duckdb：大表本地 SQL 聚合

**功能**：对 CSV/Parquet/JSON 大表直接跑 SQL——计数/分组/join/去重/抽样/导出；文件即表，不需要装服务或写加载代码。

工具走 PATH 直呼 `duckdb`（单二进制，bootstrap 部署到 `~/.local/bin/duckdb`；缺失跑仓库根 `scripts/bootstrap.sh`）。文件即表：SQL 里 `FROM 'data.csv'` 直接查，毫秒级出聚合——把"全量数据喂模型"降级为"聚合后只看 5 行"。

## 纪律

**先 `count(*)` 摸底，查询永远 `LIMIT` 收尾**；禁止 `cat`/整读大文件灌上下文。

## 命令模板

```bash
duckdb -c "SELECT count(*) FROM 'data.csv'"                            # 摸底行数
duckdb -c "SELECT col, count(*) n FROM 'data.csv' GROUP BY 1 ORDER BY n DESC LIMIT 5"
duckdb -c "SELECT * FROM 'a.parquet' WHERE id IN (SELECT id FROM 'b.csv') LIMIT 10"   # 跨格式 join
duckdb -c "SELECT k, sum(n) FROM read_json_auto('/x/*.json') GROUP BY 1"              # NDJSON/JSON
duckdb -c "COPY (SELECT * FROM 'in.csv' WHERE ok) TO 'out.parquet' (FORMAT parquet)"  # 清洗落盘
```

路径直接写进 SQL 字符串（自动 read_csv_auto 嗅探类型与表头）；中文列名/值用双引号包裹。

## 坑

- 类型嗅探会猜列型：要原始形态用 `read_csv('f.csv', all_varchar=true)`
- 异常分隔符/无表头：`read_csv('f', delim=';', header=false)` 显式传参
- 交互式探索直接裸敲 `duckdb` 进 REPL（`.quit` 退出），比反复 `-c` 顺手

## 自检

```bash
printf 'a,b\nx,1\nx,2\ny,3\n' > /tmp/ddb_check.csv && duckdb -c "SELECT a, count(*) FROM '/tmp/ddb_check.csv' GROUP BY 1 ORDER BY 2 DESC"
```

期望：x=2 / y=1 两行。
