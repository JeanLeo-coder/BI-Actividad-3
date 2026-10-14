-- ============================================================================
-- VALIDACIÓN TÉCNICA Y CONTEOS DE CONTROL (PASO 6)
-- Comprueba que el grano no se altera y verifica totales manuales contra el reporte.
-- ============================================================================

USE moda_urbana_dm;

-- Control 1: Verificar volumen por trimestre y ausencia de duplicados en FACT_VENTAS
SELECT
    dt.anio,
    dt.trimestre,
    COUNT(fv.linea_id) AS total_lineas,
    COUNT(DISTINCT fv.orden_id) AS total_ordenes,
    ROUND(SUM(fv.precio_lista_total), 2) AS suma_precio_lista,
    ROUND(SUM(fv.descuento_total), 2) AS suma_descuento,
    ROUND(SUM(fv.venta_neta), 2) AS suma_venta_neta
FROM FACT_VENTAS fv
INNER JOIN DIM_TIEMPO dt ON fv.fecha_key = dt.fecha_key
GROUP BY dt.anio, dt.trimestre;

-- Control 2: Demostración del error de multiplicación (Fan-Out) al hacer LEFT JOIN directo
-- vs Pre-agregación en CTE (Evidencia de por qué se corrigió la consulta inicial de IA)
SELECT
    (SELECT ROUND(SUM(venta_neta), 2) FROM FACT_VENTAS) AS venta_neta_real_sin_join,
    (SELECT ROUND(SUM(fv.venta_neta), 2)
     FROM FACT_VENTAS fv
     LEFT JOIN FACT_DEVOLUCIONES fd ON fv.linea_id = fd.linea_id) AS venta_neta_inflada_join_directo,
    (SELECT ROUND(SUM(fv.venta_neta), 2)
     FROM FACT_VENTAS fv
     LEFT JOIN (SELECT linea_id, SUM(importe_devuelto) AS dev FROM FACT_DEVOLUCIONES GROUP BY linea_id) cdl
       ON fv.linea_id = cdl.linea_id) AS venta_neta_correcta_con_cte;

-- Control 3: Muestra controlada para verificar manualmente el #1 de Región Norte (producto_key = 1)
SELECT
    dt.trimestre,
    COUNT(fv.linea_id) AS lineas_vendidas,
    SUM(fv.cantidad) AS unidades_vendidas,
    ROUND(SUM(fv.venta_neta), 2) AS venta_neta_bruta,
    ROUND(SUM(COALESCE(cdl.total_devuelto_linea, 0)), 2) AS devoluciones_aplicadas,
    ROUND(SUM(fv.venta_neta - COALESCE(cdl.total_devuelto_linea, 0)), 2) AS rentabilidad_neta_verificada
FROM FACT_VENTAS fv
INNER JOIN DIM_TIEMPO dt ON fv.fecha_key = dt.fecha_key
INNER JOIN DIM_SUCURSAL ds ON fv.sucursal_venta_key = ds.sucursal_key
LEFT JOIN (
    SELECT linea_id, SUM(importe_devuelto) AS total_devuelto_linea
    FROM FACT_DEVOLUCIONES
    WHERE tipo_movimiento = 'devolucion'
    GROUP BY linea_id
) cdl ON fv.linea_id = cdl.linea_id
WHERE ds.region = 'Norte'
  AND fv.producto_key = 1
  AND dt.anio = 2026
GROUP BY dt.trimestre;
