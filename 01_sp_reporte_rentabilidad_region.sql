-- ============================================================================
-- ENTREGABLE 8 (PASO 9): STORED PROCEDURE PARAMETRIZADO Y PRUEBA DE EJECUCIÓN
-- Empresa: Moda Urbana · Motor: MySQL 8.0
-- Parámetros:
--   p_anio           INT (Ej. 2026)
--   p_trim_actual    INT (Ej. 2 para el segundo trimestre)
--   p_trim_anterior  INT (Ej. 1 para el primer trimestre)
--   p_top_n          INT (Ej. 5 para el Top 5 por región)
-- ============================================================================

USE moda_urbana_dm;

DROP PROCEDURE IF EXISTS sp_top_productos_rentables_region;

DELIMITER $$

CREATE PROCEDURE sp_top_productos_rentables_region(
    IN p_anio INT,
    IN p_trim_actual INT,
    IN p_trim_anterior INT,
    IN p_top_n INT
)
BEGIN
    -- Validación defensiva de parámetros de entrada
    IF p_trim_actual NOT IN (1, 2, 3, 4) OR p_trim_anterior NOT IN (1, 2, 3, 4) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Los trimestres deben estar comprendidos entre 1 y 4.';
    END IF;

    IF p_top_n IS NULL OR p_top_n <= 0 THEN
        SET p_top_n = 5;
    END IF;

    -- Consulta validada parametrizada con CTEs y función de ventana
    WITH cte_devoluciones_linea AS (
        SELECT
            linea_id,
            SUM(importe_devuelto) AS total_devuelto_linea
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
            SUM(CASE WHEN dt.trimestre = p_trim_actual THEN (fv.venta_neta - COALESCE(cdl.total_devuelto_linea, 0)) ELSE 0 END) AS rentabilidad_periodo_actual,
            SUM(CASE WHEN dt.trimestre = p_trim_anterior THEN (fv.venta_neta - COALESCE(cdl.total_devuelto_linea, 0)) ELSE 0 END) AS rentabilidad_periodo_anterior,
            COUNT(CASE WHEN dt.trimestre = p_trim_anterior THEN fv.linea_id END) AS lineas_periodo_anterior
        FROM FACT_VENTAS fv
        INNER JOIN DIM_TIEMPO dt ON fv.fecha_key = dt.fecha_key
        INNER JOIN DIM_SUCURSAL ds ON fv.sucursal_venta_key = ds.sucursal_key
        INNER JOIN DIM_PRODUCTO dp ON fv.producto_key = dp.producto_key
        LEFT JOIN cte_devoluciones_linea cdl ON fv.linea_id = cdl.linea_id
        WHERE dt.anio = p_anio
          AND dt.trimestre IN (p_trim_actual, p_trim_anterior)
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
        SELECT
            region,
            DENSE_RANK() OVER (
                PARTITION BY region
                ORDER BY rentabilidad_periodo_actual DESC
            ) AS posicion_region,
            producto_key,
            sku,
            CONCAT(nombre_producto, ' (', talla, ' · ', color, ')') AS producto_variante,
            coleccion,
            ROUND(rentabilidad_periodo_actual, 2) AS rentabilidad_q_actual,
            ROUND(rentabilidad_periodo_anterior, 2) AS rentabilidad_q_anterior,
            ROUND(rentabilidad_periodo_actual - rentabilidad_periodo_anterior, 2) AS variacion_absoluta,
            ROUND(
                ((rentabilidad_periodo_actual - rentabilidad_periodo_anterior) * 100.0) / NULLIF(rentabilidad_periodo_anterior, 0),
                2
            ) AS variacion_porcentual,
            CASE
                WHEN lineas_periodo_anterior = 0 OR rentabilidad_periodo_anterior = 0
                    THEN CONCAT('SIN DATOS EN Q', p_trim_anterior, ' (Lanzamiento Q', p_trim_actual, ')')
                ELSE CONCAT('CON HISTORIAL Q', p_trim_anterior)
            END AS indicador_periodo_anterior
        FROM cte_rentabilidad_trimestral
        WHERE rentabilidad_periodo_actual > 0
    )
    SELECT
        region,
        posicion_region,
        producto_key,
        sku,
        producto_variante,
        coleccion,
        rentabilidad_q_actual AS rentabilidad_q2_2026,
        rentabilidad_q_anterior AS rentabilidad_q1_2026,
        variacion_absoluta,
        variacion_porcentual,
        indicador_periodo_anterior
    FROM cte_ranking_regional
    WHERE posicion_region <= p_top_n
    ORDER BY region ASC, posicion_region ASC;
END$$

DELIMITER ;

-- ============================================================================
-- LLAMADA DE PRUEBA OFICIAL (Comparando Q2 2026 vs Q1 2026, Top 5 por región)
-- ============================================================================
CALL sp_top_productos_rentables_region(2026, 2, 1, 5);
