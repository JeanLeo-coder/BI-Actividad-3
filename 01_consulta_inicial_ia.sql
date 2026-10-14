-- ============================================================================
-- ENTREGABLE 5 (PARTE A): CONSULTA INICIAL GENERADA POR LA IA (ANTES DE CORRECCIÓN)
-- Estado: REVISADA Y DESCARTADA POR EL EQUIPO 3
-- Defectos identificados en la revisión de escritorio:
--   1. Utiliza fv.sucursal_entrega_key en lugar de fv.sucursal_venta_key.
--   2. Realiza LEFT JOIN directo con FACT_DEVOLUCIONES (relación 1:N), lo que
--      duplica fv.venta_neta cuando una línea tiene más de una devolución parcial
--      (sobreestimando las ventas netas en $14,462.00 en la base de prueba).
--   3. Omite filtrar fd.tipo_movimiento = 'devolucion' y omite mostrar talla/color.
-- ============================================================================

USE moda_urbana_dm;

WITH ventas_regionales AS (
    SELECT
        ds.region,
        dp.producto_key,
        dp.sku,
        dp.nombre,
        SUM(CASE WHEN dt.trimestre = 2 THEN fv.venta_neta - COALESCE(fd.importe_devuelto, 0) ELSE 0 END) AS rentabilidad_q2_2026,
        SUM(CASE WHEN dt.trimestre = 1 THEN fv.venta_neta - COALESCE(fd.importe_devuelto, 0) ELSE 0 END) AS rentabilidad_q1_2026
    FROM FACT_VENTAS fv
    INNER JOIN DIM_TIEMPO dt ON fv.fecha_key = dt.fecha_key
    INNER JOIN DIM_SUCURSAL ds ON fv.sucursal_entrega_key = ds.sucursal_key
    INNER JOIN DIM_PRODUCTO dp ON fv.producto_key = dp.producto_key
    LEFT JOIN FACT_DEVOLUCIONES fd ON fv.linea_id = fd.linea_id
    WHERE dt.anio = 2026 AND dt.trimestre IN (1, 2)
    GROUP BY ds.region, dp.producto_key, dp.sku, dp.nombre
),
ranking AS (
    SELECT
        region,
        ROW_NUMBER() OVER (PARTITION BY region ORDER BY rentabilidad_q2_2026 DESC) AS posicion_region,
        producto_key,
        sku,
        nombre,
        rentabilidad_q2_2026,
        rentabilidad_q1_2026,
        (rentabilidad_q2_2026 - rentabilidad_q1_2026) AS variacion_absoluta,
        ((rentabilidad_q2_2026 - rentabilidad_q1_2026) / NULLIF(rentabilidad_q1_2026, 0)) * 100 AS variacion_porcentual,
        CASE WHEN rentabilidad_q1_2026 = 0 THEN 'Sin datos en Q1' ELSE 'Activo en Q1' END AS indicador_periodo_anterior
    FROM ventas_regionales
)
SELECT * FROM ranking WHERE posicion_region <= 5 ORDER BY region, posicion_region;
