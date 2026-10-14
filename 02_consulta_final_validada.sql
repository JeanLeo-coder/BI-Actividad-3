-- ============================================================================
-- ENTREGABLE 5 (PARTE B): CONSULTA SQL FINAL VALIDADA POR EL EQUIPO 3
-- Empresa: Moda Urbana (Caso Retail 3) · Motor: MySQL 8.0
-- Grano de FACT_VENTAS: Una fila representa una variante de producto vendida
--                       dentro de una línea de una orden de compra (linea_id).
-- Mejoras aplicadas por el Equipo 3:
--   1. CTE `cte_devoluciones_linea`: Pre-agrega las devoluciones por `linea_id`
--      para garantizar una relación 1:1 al hacer LEFT JOIN con FACT_VENTAS,
--      evitando duplicar `venta_neta` cuando existen múltiples devoluciones parciales.
--   2. CTE `cte_rentabilidad_trimestral`: Une con `DIM_SUCURSAL` usando el rol
--      comercial `sucursal_venta_key` y agrupa a nivel variante (SKU, talla, color).
--   3. CTE `cte_ranking_regional`: Aplica `DENSE_RANK() OVER (PARTITION BY region ...)`
--      y protege el cálculo porcentual con `NULLIF(rentabilidad_q1_2026, 0)`.
-- ============================================================================

USE moda_urbana_dm;

WITH cte_devoluciones_linea AS (
    -- Etapa 1: Pre-agregar devoluciones al grano de FACT_VENTAS (1 fila por linea_id)
    SELECT
        linea_id,
        SUM(importe_devuelto) AS total_devuelto_linea
    FROM FACT_DEVOLUCIONES
    WHERE tipo_movimiento = 'devolucion'
    GROUP BY linea_id
),
cte_rentabilidad_trimestral AS (
    -- Etapa 2: Consolidar rentabilidad neta en Q1 y Q2 2026 por región y variante
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
    WHERE dt.anio = 2026
      AND dt.trimestre IN (1, 2)
    GROUP BY
        ds.region,
        dp.producto_key,
        dp.sku,
        dp.nombre,
        dp.talla,
        dp.color,
        dp.coleccion
),
cte_ranking_regional AS (
    -- Etapa 3: Clasificar con función de ventana por región y calcular variaciones
    SELECT
        region,
        DENSE_RANK() OVER (
            PARTITION BY region
            ORDER BY rentabilidad_q2_2026 DESC
        ) AS posicion_region,
        producto_key,
        sku,
        CONCAT(nombre_producto, ' (', talla, ' · ', color, ')') AS producto_variante,
        coleccion,
        ROUND(rentabilidad_q2_2026, 2) AS rentabilidad_q2_2026,
        ROUND(rentabilidad_q1_2026, 2) AS rentabilidad_q1_2026,
        ROUND(rentabilidad_q2_2026 - rentabilidad_q1_2026, 2) AS variacion_absoluta,
        ROUND(
            ((rentabilidad_q2_2026 - rentabilidad_q1_2026) * 100.0) / NULLIF(rentabilidad_q1_2026, 0),
            2
        ) AS variacion_porcentual,
        CASE
            WHEN lineas_q1 = 0 OR rentabilidad_q1_2026 = 0 THEN 'SIN DATOS EN Q1 (Lanzamiento Q2)'
            ELSE 'CON HISTORIAL Q1'
        END AS indicador_periodo_anterior
    FROM cte_rentabilidad_trimestral
    WHERE rentabilidad_q2_2026 > 0
)
SELECT
    region,
    posicion_region,
    producto_key,
    sku,
    producto_variante,
    coleccion,
    rentabilidad_q2_2026,
    rentabilidad_q1_2026,
    variacion_absoluta,
    variacion_porcentual,
    indicador_periodo_anterior
FROM cte_ranking_regional
WHERE posicion_region <= 5
ORDER BY region ASC, posicion_region ASC;
