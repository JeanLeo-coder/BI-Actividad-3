-- ============================================================================
-- ENTREGABLE 6 (PASO 7): DEPURACIÓN DEL ERROR DE AGRUPACIÓN 1055 EN MYSQL 8.0
-- ============================================================================

USE moda_urbana_dm;

-- Asegurar que el modo estricto estándar de MySQL 8.0 esté activo:
SET SESSION sql_mode = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- ----------------------------------------------------------------------------
-- 1. CONSULTA DEFECTUOSA (Agrupación incompleta que provoca el Error 1055)
-- Selecciona región, identificador, SKU y nombre del producto junto con SUM(venta_neta),
-- pero en la cláusula GROUP BY únicamente agrupa por `ds.region`.
-- ----------------------------------------------------------------------------
/*
SELECT
    ds.region,
    dp.producto_key,
    dp.sku,
    dp.nombre AS nombre_producto,
    SUM(fv.venta_neta) AS venta_neta_regional
FROM FACT_VENTAS fv
INNER JOIN DIM_SUCURSAL ds ON fv.sucursal_venta_key = ds.sucursal_key
INNER JOIN DIM_PRODUCTO dp ON fv.producto_key = dp.producto_key
INNER JOIN DIM_TIEMPO dt ON fv.fecha_key = dt.fecha_key
WHERE dt.anio = 2026 AND dt.trimestre = 2
GROUP BY ds.region;
*/

-- ----------------------------------------------------------------------------
-- 2. MENSAJE DE ERROR OBTENIDO EN MYSQL 8.0
-- ----------------------------------------------------------------------------
-- ERROR 1055 (42000): Expression #2 of SELECT list is not in GROUP BY clause
-- and contains nonaggregated column 'moda_urbana_dm.dp.producto_key' which is
-- not functionally dependent on columns in GROUP BY clause; this is
-- incompatible with sql_mode=only_full_group_by

-- ----------------------------------------------------------------------------
-- 3. DIAGNÓSTICO DEL EQUIPO Y EXPLICACIÓN TÉCNICA
-- ----------------------------------------------------------------------------
-- ¿Por qué ocurre?:
-- Al agrupar únicamente por `ds.region`, MySQL colapsa todas las ventas de una
-- región en una sola fila resumen. Sin embargo, dentro de una región se vendieron
-- 36 variantes distintas (`dp.producto_key`, `dp.sku`, `dp.nombre`). Como
-- `producto_key` no depende funcionalmente de `region`, el motor no puede saber
-- qué producto mostrar en esa única fila regional, rechazando la consulta bajo
-- `ONLY_FULL_GROUP_BY`.
--
-- ¿Por qué la corrección es coherente con el negocio?:
-- El reto de negocio exige evaluar la rentabilidad de CADA PRODUCTO DENTRO DE CADA
-- REGIÓN (grano del reporte = Región + Producto/Variante). Por ello, debemos
-- incluir `dp.producto_key` (y sus atributos descriptivos `sku`, `nombre`, `talla`,
-- `color`) en la cláusula `GROUP BY`. En MySQL 8.0, dado que `dp.producto_key` es
-- la PRIMARY KEY de `DIM_PRODUCTO`, `sku`, `nombre`, `talla` y `color` tienen
-- dependencia funcional directa de `dp.producto_key`, pero declararlos explícitamente
-- en el `GROUP BY` garantiza compatibilidad ANSI SQL total.

-- ----------------------------------------------------------------------------
-- 4. VERSIÓN CORREGIDA Y VALIDADA
-- ----------------------------------------------------------------------------
SELECT
    ds.region,
    dp.producto_key,
    dp.sku,
    dp.nombre AS nombre_producto,
    dp.talla,
    dp.color,
    ROUND(SUM(fv.venta_neta), 2) AS venta_neta_regional
FROM FACT_VENTAS fv
INNER JOIN DIM_SUCURSAL ds ON fv.sucursal_venta_key = ds.sucursal_key
INNER JOIN DIM_PRODUCTO dp ON fv.producto_key = dp.producto_key
INNER JOIN DIM_TIEMPO dt ON fv.fecha_key = dt.fecha_key
WHERE dt.anio = 2026 AND dt.trimestre = 2
GROUP BY
    ds.region,
    dp.producto_key,
    dp.sku,
    dp.nombre,
    dp.talla,
    dp.color
ORDER BY ds.region ASC, venta_neta_regional DESC;
