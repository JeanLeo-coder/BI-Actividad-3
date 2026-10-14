-- ============================================================================
-- ENTREGABLE 7 (PASO 8): OPTIMIZACIÓN CON EXPLAIN (ANTES Y DESPUÉS)
-- Motor: MySQL 8.0
-- ============================================================================

USE moda_urbana_dm;

-- ----------------------------------------------------------------------------
-- PASO 1: EJECUTAR EXPLAIN ANTES DE CREAR ÍNDICES SECUNDARIOS COMPUESTOS
-- ----------------------------------------------------------------------------
-- En el DDL base de la Unidad 2, solo existen índices simples sobre las PK y FK.
-- Al ejecutar EXPLAIN sobre la consulta final validada:
-- 1) `DIM_TIEMPO` realiza un barrido completo (`type = ALL`, 181 filas, `Using where`)
--    porque filtra por `dt.anio = 2026 AND dt.trimestre IN (1, 2)`, columnas sin índice.
-- 2) La CTE `cte_devoluciones_linea` escanea toda la tabla `FACT_DEVOLUCIONES`
--    (`type = ALL`, 149 filas, `Using where; Using temporary`) porque filtra por
--    `tipo_movimiento = 'devolucion'` y agrupa por `linea_id`.
-- 3) El agregador principal en `FACT_VENTAS` requiere leer las filas por FK y armar
--    una tabla temporal (`Using temporary`) para resolver el `GROUP BY ds.region, dp.producto_key`.

EXPLAIN
WITH cte_devoluciones_linea AS (
    SELECT linea_id, SUM(importe_devuelto) AS total_devuelto_linea
    FROM FACT_DEVOLUCIONES
    WHERE tipo_movimiento = 'devolucion'
    GROUP BY linea_id
),
cte_rentabilidad_trimestral AS (
    SELECT
        ds.region,
        dp.producto_key,
        dp.sku,
        dp.nombre AS nombre_producto,
        dp.talla,
        dp.color,
        dp.coleccion,
        SUM(CASE WHEN dt.trimestre = 2 THEN (fv.venta_neta - COALESCE(cdl.total_devuelto_linea, 0)) ELSE 0 END) AS rentabilidad_q2_2026,
        SUM(CASE WHEN dt.trimestre = 1 THEN (fv.venta_neta - COALESCE(cdl.total_devuelto_linea, 0)) ELSE 0 END) AS rentabilidad_q1_2026,
        COUNT(CASE WHEN dt.trimestre = 1 THEN fv.linea_id END) AS lineas_q1
    FROM FACT_VENTAS fv
    INNER JOIN DIM_TIEMPO dt ON fv.fecha_key = dt.fecha_key
    INNER JOIN DIM_SUCURSAL ds ON fv.sucursal_venta_key = ds.sucursal_key
    INNER JOIN DIM_PRODUCTO dp ON fv.producto_key = dp.producto_key
    LEFT JOIN cte_devoluciones_linea cdl ON fv.linea_id = cdl.linea_id
    WHERE dt.anio = 2026 AND dt.trimestre IN (1, 2)
    GROUP BY ds.region, dp.producto_key, dp.sku, dp.nombre, dp.talla, dp.color, dp.coleccion
),
cte_ranking_regional AS (
    SELECT
        region,
        DENSE_RANK() OVER (PARTITION BY region ORDER BY rentabilidad_q2_2026 DESC) AS posicion_region,
        producto_key, sku,
        CONCAT(nombre_producto, ' (', talla, ' · ', color, ')') AS producto_variante,
        coleccion,
        ROUND(rentabilidad_q2_2026, 2) AS rentabilidad_q2_2026,
        ROUND(rentabilidad_q1_2026, 2) AS rentabilidad_q1_2026,
        ROUND(rentabilidad_q2_2026 - rentabilidad_q1_2026, 2) AS variacion_absoluta,
        ROUND(((rentabilidad_q2_2026 - rentabilidad_q1_2026) * 100.0) / NULLIF(rentabilidad_q1_2026, 0), 2) AS variacion_porcentual,
        CASE WHEN lineas_q1 = 0 OR rentabilidad_q1_2026 = 0 THEN 'SIN DATOS EN Q1 (Lanzamiento Q2)' ELSE 'CON HISTORIAL Q1' END AS indicador_periodo_anterior
    FROM cte_rentabilidad_trimestral
    WHERE rentabilidad_q2_2026 > 0
)
SELECT * FROM cte_ranking_regional WHERE posicion_region <= 5 ORDER BY region ASC, posicion_region ASC;

-- ----------------------------------------------------------------------------
-- PASO 2: APLICAR MEJORA — CREACIÓN DE 3 ÍNDICES COMPUESTOS CUBRIENTES (COVERING INDEXES)
-- ----------------------------------------------------------------------------

-- Índice 1: Cubre el filtro por año y trimestre en DIM_TIEMPO e incluye fecha_key (Using index)
CREATE INDEX idx_dt_anio_trim_fecha
    ON DIM_TIEMPO (anio, trimestre, fecha_key);

-- Índice 2: Cubre el filtro WHERE tipo_movimiento = 'devolucion', el GROUP BY linea_id
-- y la suma SUM(importe_devuelto) en FACT_DEVOLUCIONES sin tocar las páginas de datos (Index-Only Scan)
CREATE INDEX idx_fd_tipo_linea_importe
    ON FACT_DEVOLUCIONES (tipo_movimiento, linea_id, importe_devuelto);

-- Índice 3: Cubre los JOINs de FACT_VENTAS (fecha_key, sucursal_venta_key, producto_key)
-- e incluye linea_id y venta_neta para resolver la agregación directamente desde el índice
CREATE INDEX idx_fv_fecha_suc_prod_neta
    ON FACT_VENTAS (fecha_key, sucursal_venta_key, producto_key, linea_id, venta_neta);

-- Actualizar estadísticas del optimizador:
ANALYZE TABLE DIM_TIEMPO, FACT_DEVOLUCIONES, FACT_VENTAS, DIM_SUCURSAL, DIM_PRODUCTO;

-- ----------------------------------------------------------------------------
-- PASO 3: EJECUTAR EXPLAIN DESPUÉS DE LOS ÍNDICES COMPUESTOS
-- ----------------------------------------------------------------------------
-- Efecto observado en el plan de ejecución:
-- 1) `DIM_TIEMPO` pasa de `type = ALL` a `type = range` usando `idx_dt_anio_trim_fecha` con `Using where; Using index`.
-- 2) `FACT_DEVOLUCIONES` (en `cte_devoluciones_linea`) pasa de `type = ALL` (`Using temporary`)
--    a `type = ref` usando `idx_fd_tipo_linea_importe` con `Using where; Using index` (eliminando la tabla temporal).
-- 3) `FACT_VENTAS` utiliza el índice cubriente `idx_fv_fecha_suc_prod_neta` (`Using index`),
--    evitando lecturas aleatorias a disco en la tabla de hechos.

EXPLAIN
WITH cte_devoluciones_linea AS (
    SELECT linea_id, SUM(importe_devuelto) AS total_devuelto_linea
    FROM FACT_DEVOLUCIONES
    WHERE tipo_movimiento = 'devolucion'
    GROUP BY linea_id
),
cte_rentabilidad_trimestral AS (
    SELECT
        ds.region,
        dp.producto_key,
        dp.sku,
        dp.nombre AS nombre_producto,
        dp.talla,
        dp.color,
        dp.coleccion,
        SUM(CASE WHEN dt.trimestre = 2 THEN (fv.venta_neta - COALESCE(cdl.total_devuelto_linea, 0)) ELSE 0 END) AS rentabilidad_q2_2026,
        SUM(CASE WHEN dt.trimestre = 1 THEN (fv.venta_neta - COALESCE(cdl.total_devuelto_linea, 0)) ELSE 0 END) AS rentabilidad_q1_2026,
        COUNT(CASE WHEN dt.trimestre = 1 THEN fv.linea_id END) AS lineas_q1
    FROM FACT_VENTAS fv
    INNER JOIN DIM_TIEMPO dt ON fv.fecha_key = dt.fecha_key
    INNER JOIN DIM_SUCURSAL ds ON fv.sucursal_venta_key = ds.sucursal_key
    INNER JOIN DIM_PRODUCTO dp ON fv.producto_key = dp.producto_key
    LEFT JOIN cte_devoluciones_linea cdl ON fv.linea_id = cdl.linea_id
    WHERE dt.anio = 2026 AND dt.trimestre IN (1, 2)
    GROUP BY ds.region, dp.producto_key, dp.sku, dp.nombre, dp.talla, dp.color, dp.coleccion
),
cte_ranking_regional AS (
    SELECT
        region,
        DENSE_RANK() OVER (PARTITION BY region ORDER BY rentabilidad_q2_2026 DESC) AS posicion_region,
        producto_key, sku,
        CONCAT(nombre_producto, ' (', talla, ' · ', color, ')') AS producto_variante,
        coleccion,
        ROUND(rentabilidad_q2_2026, 2) AS rentabilidad_q2_2026,
        ROUND(rentabilidad_q1_2026, 2) AS rentabilidad_q1_2026,
        ROUND(rentabilidad_q2_2026 - rentabilidad_q1_2026, 2) AS variacion_absoluta,
        ROUND(((rentabilidad_q2_2026 - rentabilidad_q1_2026) * 100.0) / NULLIF(rentabilidad_q1_2026, 0), 2) AS variacion_porcentual,
        CASE WHEN lineas_q1 = 0 OR rentabilidad_q1_2026 = 0 THEN 'SIN DATOS EN Q1 (Lanzamiento Q2)' ELSE 'CON HISTORIAL Q1' END AS indicador_periodo_anterior
    FROM cte_rentabilidad_trimestral
    WHERE rentabilidad_q2_2026 > 0
)
SELECT * FROM cte_ranking_regional WHERE posicion_region <= 5 ORDER BY region ASC, posicion_region ASC;
