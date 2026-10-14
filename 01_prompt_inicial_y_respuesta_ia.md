# Entregable 4: Prompts de IA, Respuesta Original y Registro de Iteraciones

## 1. Prompt Completo Redactado por el Equipo 3 (Siguiendo Plantilla Oficial)

```text
Actúa como analista SQL experto para MySQL 8.0.
Trabajamos con la empresa retail "Moda Urbana" (cadena de moda rápida, calzado y accesorios) y necesitamos construir un reporte empresarial que identifique los 5 productos (variantes) con mayor rentabilidad en cada región comercial durante el segundo trimestre de 2026 (Q2 2026) y muestre su variación absoluta y porcentual frente al primer trimestre de 2026 (Q1 2026).

El grano de la tabla de hechos principal (FACT_VENTAS) es:
Una fila representa una variante específica de producto (combinación única de SKU, talla y color) vendida dentro de una línea de una orden de compra (identificada por linea_id).

El esquema estrella disponible en nuestro Data Mart (diseñado en la Unidad 2) es estrictamente el siguiente:
- FACT_VENTAS (alias fv): linea_id (PK), orden_id, cliente_key (FK), producto_key (FK), sucursal_venta_key (FK), sucursal_entrega_key (FK), canal_key (FK), fecha_key (FK), cupon_key (FK nullable), cantidad, precio_lista_total, descuento_total, venta_neta, tipo_precio ('regular', 'liquidacion', 'promocion').
- FACT_DEVOLUCIONES (alias fd): devolucion_key (PK), producto_key (FK), sucursal_key (FK), fecha_key (FK), motivo_key (FK), linea_id (FK hacia FACT_VENTAS.linea_id), tipo_movimiento ('devolucion', 'reemplazo'), importe_devuelto.
- DIM_TIEMPO (alias dt): fecha_key (PK), fecha, anio, mes, trimestre, temporada_comercial.
- DIM_SUCURSAL (alias ds): sucursal_key (PK), sucursal_id, nombre, ciudad, region ('Norte', 'Centro', 'Occidente', 'Sur'), tipo_tienda.
- DIM_PRODUCTO (alias dp): producto_key (PK), variante_id, sku, talla, color, nombre, categoria, coleccion, temporada, marca.

Las reglas de negocio para calcular la rentabilidad y filtrar registros son:
1. Nuestro modelo de Unidad 2 NO tiene columna de costo unitario. No inventes columnas inexistentes. Define la rentabilidad como la Rentabilidad Comercial Neta (Ingreso Neto Efectivo Post-Devoluciones): venta_neta menos el importe_devuelto asociado a la línea de venta cuando fd.tipo_movimiento = 'devolucion'.
2. La región comercial corresponde a la sucursal donde se originó la venta (fv.sucursal_venta_key = ds.sucursal_key).
3. Se deben comparar los periodos Q2 2026 (dt.anio = 2026 AND dt.trimestre = 2) frente a Q1 2026 (dt.anio = 2026 AND dt.trimestre = 1).
4. Una misma linea_id en FACT_VENTAS puede tener múltiples devoluciones parciales en FACT_DEVOLUCIONES (relación 1:N).

La salida debe contener:
- region
- posicion_region (Top 1 a 5 dentro de cada región según rentabilidad Q2 2026 descendente)
- producto_key, sku, producto_variante (nombre, talla y color) y coleccion
- rentabilidad_q2_2026
- rentabilidad_q1_2026
- variacion_absoluta (Q2 - Q1)
- variacion_porcentual ((Q2 - Q1) / Q1 * 100)
- indicador_periodo_anterior (que identifique claramente cuando un producto no tuvo ventas en Q1 2026)

Antes de escribir el código SQL, enumera tus supuestos. Después presenta la consulta usando CTEs, JOINs explícitos y una función de ventana, explicando cómo evitas duplicar importes por JOIN y cómo previenes la división entre cero.
```

---

## 2. Primera Respuesta Obtenida de la IA (Propuesta Inicial)

### Supuestos declarados por la IA en su primera respuesta:
1. Se asume que `FACT_VENTAS.venta_neta` ya tiene descontado `descuento_total`.
2. Se une `FACT_VENTAS` con `FACT_DEVOLUCIONES` mediante `LEFT JOIN` directo por `linea_id` para restar `fd.importe_devuelto`.
3. Se utiliza `ROW_NUMBER() OVER (PARTITION BY ds.region ORDER BY rentabilidad_q2 DESC)` para limitar a 5 productos por región.

### Consulta Inicial Propuesta por la IA (`01_consulta_inicial_ia.sql`):
```sql
-- PROPUESTA INICIAL DE LA IA (CONTIENE 3 DEFECTOS DETECTADOS EN AUDITORÍA)
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
    INNER JOIN DIM_SUCURSAL ds ON fv.sucursal_entrega_key = ds.sucursal_key -- Defecto 1: usó sucursal_entrega_key en vez de sucursal_venta_key
    INNER JOIN DIM_PRODUCTO dp ON fv.producto_key = dp.producto_key
    LEFT JOIN FACT_DEVOLUCIONES fd ON fv.linea_id = fd.linea_id             -- Defecto 2: JOIN 1:N directo duplica fv.venta_neta en líneas con >1 devolución parcial
    WHERE dt.anio = 2026 AND dt.trimestre IN (1, 2)
    GROUP BY ds.region, dp.producto_key, dp.sku, dp.nombre
),
ranking AS (
    SELECT
        region,
        ROW_NUMBER() OVER (PARTITION BY region ORDER BY rentabilidad_q2_2026 DESC) AS posicion_region, -- Defecto 3: ROW_NUMBER corta empates arbitrariamente y omitió talla/color
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
```

---

## 3. Registro de Decisiones y Auditoría del Equipo sobre la Propuesta de IA

| # | Aspecto Evaluado | Propuesta Inicial de la IA | Decisión del Equipo 3 | Evidencia Técnica / Prueba de Control |
| :-: | :--- | :--- | :--- | :--- |
| **1** | **Prevención de duplicación de importes (Efecto Fan-Out en JOIN 1:N)** | Hizo `LEFT JOIN FACT_DEVOLUCIONES fd ON fv.linea_id = fd.linea_id` directamente dentro de la consulta de agregación de ventas. | **RECHAZADA Y CORREGIDA.** Se creó una primera CTE independiente `cte_devoluciones_linea` que agrupa `SUM(importe_devuelto)` por `linea_id` filtrando `tipo_movimiento = 'devolucion'` antes de unir con `FACT_VENTAS`. | En la prueba de control, 4 líneas con múltiples devoluciones parciales provocaban que el `LEFT JOIN` directo inflara `SUM(fv.venta_neta)` de **`$3,478,199.60`** a **`$3,492,661.60`** (**`+$14,462.00` duplicados**). Con la CTE pre-agregada el error es `$0.00`. |
| **2** | **Rol de la dimensión `DIM_SUCURSAL` para Región** | En un borrador usó `fv.sucursal_entrega_key = ds.sucursal_key`. | **CORREGIDA.** Se fijó explícitamente `fv.sucursal_venta_key = ds.sucursal_key`. | Según la regla de negocio del Caso 3 (Click & Collect se vende en línea y se entrega en tienda), la venta pertenece comercialmente a `sucursal_venta_key`. |
| **3** | **Atributos de Variante (`talla` y `color`)** | Solo mostró `dp.nombre` y `dp.sku` en la salida. | **ENRIQUECIDA.** Se incluyeron `dp.talla`, `dp.color` y `dp.coleccion` en el `GROUP BY` y se formateó `CONCAT(nombre_producto, ' (', talla, ' · ', color, ')')`. | La restricción del caso Moda Urbana exige analizar a nivel variante (talla y color), no solo por nombre genérico de prenda. |
| **4** | **Función de ventana (`ROW_NUMBER` vs `DENSE_RANK`)** | Propuso `ROW_NUMBER() OVER (...)`. | **MEJORADA A `DENSE_RANK()`.** Se cambió a `DENSE_RANK() OVER (PARTITION BY region ORDER BY rentabilidad_q2_2026 DESC)` y se filtró `WHERE rentabilidad_q2_2026 > 0`. | `DENSE_RANK()` respeta empates exactos en rentabilidad sin saltar posiciones y mantiene intacto el Top 5 regional. |
| **5** | **División entre cero e indicador Q1** | Usó `NULLIF(rentabilidad_q1_2026, 0)` y un `CASE` simple. | **ACEPTADA Y REFINADA.** Se mantuvo `NULLIF(..., 0)` con `ROUND(..., 2)` y se verificó con `COUNT(CASE WHEN dt.trimestre = 1 THEN fv.linea_id END) = 0`. | Comprobado con el producto `producto_key = 31` (`MU-11-CH-GRI Chamarra Rompevientos Neon`), lanzado en Q2 2026 (`$0.00` en Q1, `NULL` en `%` y etiqueta `'SIN DATOS EN Q1 (Lanzamiento Q2)'`). |
