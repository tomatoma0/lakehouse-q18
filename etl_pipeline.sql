-- ==========================================
-- ETL ПАЙПЛАЙН ДЛЯ ВАРИАНТА Q18 (TPC-H)
-- ==========================================

-- 1. BRONZE (Сырые данные)
CREATE SCHEMA lakekeeper.lakehouse;

CREATE TABLE lakekeeper.lakehouse.raw_customer AS SELECT * FROM tpch.sf3.customer;
CREATE TABLE lakekeeper.lakehouse.raw_orders   AS SELECT * FROM tpch.sf3.orders;
CREATE TABLE lakekeeper.lakehouse.raw_lineitem AS SELECT * FROM tpch.sf3.lineitem;

-- 2. SILVER (Очищенные данные: крупные заказы)
CREATE TABLE lakekeeper.lakehouse.silver_large_orders AS
SELECT 
    c.name, 
    c.custkey, 
    o.orderkey, 
    o.orderdate, 
    o.totalprice, 
    sum(l.quantity) AS total_quantity
FROM lakekeeper.lakehouse.raw_customer c
JOIN lakekeeper.lakehouse.raw_orders o ON c.custkey = o.custkey
JOIN lakekeeper.lakehouse.raw_lineitem l ON o.orderkey = l.orderkey
WHERE o.orderkey IN (
    SELECT orderkey 
    FROM lakekeeper.lakehouse.raw_lineitem
    GROUP BY orderkey 
    HAVING sum(quantity) > 300
)
GROUP BY c.name, c.custkey, o.orderkey, o.orderdate, o.totalprice;

-- 3. GOLD (Витрина для BI)
CREATE TABLE lakekeeper.lakehouse.gold_q18 AS
SELECT * 
FROM lakekeeper.lakehouse.silver_large_orders
ORDER BY totalprice DESC, orderdate
LIMIT 100;

-- ==========================================
-- БЕНЧМАРК (8 таблиц с разными форматами и кодеками)
-- ==========================================
-- Пример для Parquet + ZSTD (остальные по аналогии):
SET SESSION lakekeeper.compression_codec = 'ZSTD';
CREATE TABLE lakekeeper.lakehouse.lineitem_parquet_zstd WITH (format = 'PARQUET')
AS SELECT * FROM tpch.sf3.lineitem;

-- Пример для ORC + GZIP:
SET SESSION lakekeeper.compression_codec = 'GZIP';
CREATE TABLE lakekeeper.lakehouse.lineitem_orc_gzip WITH (format = 'ORC')
AS SELECT * FROM tpch.sf3.lineitem;