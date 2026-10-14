# Entregable 3: Ficha de Decisiones de Negocio y Reglas Analíticas

**Empresa:** Moda Urbana · **Motor SQL:** MySQL 8.0  
**Objetivo del Reporte:** Identificar el Top 5 de productos/variantes con mayor rentabilidad en cada región comercial durante el 2.º trimestre de 2026 (Q2) y calcular su variación absoluta y porcentual frente al 1.er trimestre de 2026 (Q1).

## 1. Resolución de las Preguntas Previas de Negocio

| Pregunta de Control | Decisión Documentada del Equipo 3 | Justificación en el Modelo de Unidad 2 |
| :--- | :--- | :--- |
| **1. ¿Qué significa rentabilidad en Moda Urbana y qué columnas intervienen?** | **Rentabilidad Comercial Neta (Ingreso Neto Efectivo Post-Devoluciones):** `SUM(fv.venta_neta - COALESCE(cdl.total_devuelto_linea, 0))`. | En las fuentes del Caso 3 (`03_Moda_Urbana_Caso_Retail_U2.docx`) y en el DDL de Unidad 2 **no existe atributo `costo`**. Siguiendo la regla estricta de *no inventar columnas inexistentes*, la rentabilidad se mide como el flujo neto real retenido por la empresa tras deducir descuentos (`descuento_total`) y devoluciones (`FACT_DEVOLUCIONES.importe_devuelto`). |
| **2. ¿A qué dimensión corresponde la región comercial?** | Corresponde a `DIM_SUCURSAL.region` unida mediante el rol de venta: `fv.sucursal_venta_key = ds.sucursal_key`. | `FACT_VENTAS` tiene doble referencia a `DIM_SUCURSAL` (`sucursal_venta_key` y `sucursal_entrega_key`). La atribución comercial de la venta pertenece a la sucursal que originó la transacción (`sucursal_venta_key`), cubriendo las 4 regiones: `Norte`, `Centro`, `Occidente` y `Sur`. |
| **3. ¿Cómo se tratan los descuentos, cancelaciones y devoluciones?** | 1) Los descuentos ya están descontados en `fv.venta_neta` (`precio_lista_total - descuento_total`).<br>2) Las devoluciones (`FACT_DEVOLUCIONES` con `tipo_movimiento = 'devolucion'`) se **pre-agregan por `linea_id` en una CTE** antes del `LEFT JOIN` con `FACT_VENTAS`. | Una línea de venta (`linea_id`) puede sufrir múltiples devoluciones parciales (relación 1:N). Un `LEFT JOIN` directo duplicaría `fv.venta_neta` en líneas con 2 devoluciones parciales (inflando las ventas en `$14,462.00` en nuestra base). Pre-agregar por `linea_id` garantiza relación 1:1 y protege el grano. |
| **4. ¿Qué ocurre cuando un producto no tiene registros en Q1 2026?** | 1) `rentabilidad_q1_2026` toma valor `0.00`.<br>2) `variacion_absoluta` = `rentabilidad_q2_2026`.<br>3) `variacion_porcentual` usa `NULLIF(rentabilidad_q1_2026, 0)` devolviendo `NULL` (evitando división entre cero).<br>4) `indicador_periodo_anterior` muestra `'SIN DATOS EN Q1 (Lanzamiento Q2)'`. | Permite distinguir lanzamientos de temporada en Q2 (como el SKU `MU-11-CH-GRI Chamarra Rompevientos Neon` de la colección `Eco Sport`) sin distorsionar tasas porcentuales ni provocar errores aritméticos. |
| **5. ¿Cómo se comprueba que cada región devuelve máximo 5 productos?** | Mediante la función de ventana `DENSE_RANK() OVER (PARTITION BY region ORDER BY rentabilidad_q2_2026 DESC) AS posicion_region` en una CTE y el filtro externo `WHERE posicion_region <= 5`. | La cláusula `PARTITION BY region` reinicia la numeración del ranking del 1 al 5 en cada región (`Centro`, `Norte`, `Occidente`, `Sur`), generando exactamente 20 filas (5 por región). |

## 2. Fórmulas Analíticas Oficiales del Reporte

1. **Rentabilidad Neta por Línea (`linea_id`):**
   $$\text{Rentabilidad Línea} = \text{fv.venta\_neta} - \text{COALESCE}(\text{cdl.total\_devuelto\_linea}, 0)$$
2. **Rentabilidad Trimestral ($Q_1$ y $Q_2$ 2026):**
   - $R_{Q2} = \sum_{dt.\text{trimestre}=2} (\text{fv.venta\_neta} - \text{COALESCE}(\text{cdl.total\_devuelto\_linea}, 0))$
   - $R_{Q1} = \sum_{dt.\text{trimestre}=1} (\text{fv.venta\_neta} - \text{COALESCE}(\text{cdl.total\_devuelto\_linea}, 0))$
3. **Variación Absoluta ($\Delta_{\text{abs}}$):**
   $$\Delta_{\text{abs}} = \text{ROUND}(R_{Q2} - R_{Q1}, 2)$$
4. **Variación Porcentual ($\Delta_{\%}$):**
   $$\Delta_{\%} = \text{ROUND}\left(\frac{(R_{Q2} - R_{Q1}) \times 100.0}{\text{NULLIF}(R_{Q1}, 0)}, 2\right)$$

## 3. Limitación Registrada del Modelo de Unidad 2 y Propuesta de Ajuste
- **Limitación detectada:** Las tablas fuente de la Unidad 2 (`ORDENES`, `ORDEN_DETALLE`, `VARIANTES`, `PRODUCTOS`) no incluían el costo de adquisición/manufactura (`costo_unitario`), ni un catálogo de estados de orden (`Cancelada`).
- **Ajuste propuesto para evolución del Data Mart (v2.0):** Incorporar `costo_unitario DECIMAL(10,2)` en `DIM_PRODUCTO` y almacenar `costo_total DECIMAL(10,2)` y `margen_bruto DECIMAL(10,2)` en `FACT_VENTAS`, permitiendo contrastar el Margen Bruto Contable frente al Ingreso Neto Post-Devoluciones.
