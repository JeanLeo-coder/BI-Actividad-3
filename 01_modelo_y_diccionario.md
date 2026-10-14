# Entregable 1: Modelo de Referencia y Diccionario de Datos (Unidad 2 → Unidad 3)

**Empresa asignada:** Caso Retail 3 — Moda Urbana (Moda, calzado y accesorios)  
**Equipo 3:**  
- Antonio André Martínez Martínez — `2094967`  
- Erick Morán Guillén — `2103747`  
- Jean Leo Ramírez — `2102785`  

## 1. Declaración Explícita del Grano de la Tabla de Hechos (`FACT_VENTAS`)

> **Oración de Grano:** Una fila de la tabla de hechos `FACT_VENTAS` representa **una variante específica de producto (combinación única de SKU, talla y color) vendida dentro de una línea de una orden de compra**.

### Efecto del Grano sobre los Conteos Analíticos
- **Conteo de líneas de venta:** `COUNT(fv.linea_id)` devuelve el total de renglones transaccionales vendidos (1,500 líneas en la base simulada).
- **Conteo de pedidos / órdenes:** Como una orden puede contener varias líneas (distintas variantes), **no se debe usar `COUNT(*)` para contar pedidos**; se debe utilizar `COUNT(DISTINCT fv.orden_id)`.
- **Conteo de clientes únicos:** Se debe emplear `COUNT(DISTINCT fv.cliente_key)`.
- **Conteo de variantes / productos vendidos:** Se utiliza `COUNT(DISTINCT fv.producto_key)` para variantes específicas o `COUNT(DISTINCT dp.nombre)` para modelos generales de prenda.

## 2. Diagrama Estrella del Data Mart de Ventas (Unidad 2)

El diseño dimensional conserva la arquitectura construida en la Unidad 2 (`esquema_estrella_unidad_2.png`), articulada alrededor de la tabla de hechos central `FACT_VENTAS`, complementada por dos tablas de hechos auxiliares (`FACT_DEVOLUCIONES` ligada por `linea_id` y `FACT_MOVIMIENTO_LEALTAD`) y siete dimensiones conformadas (`DIM_TIEMPO`, `DIM_PRODUCTO`, `DIM_SUCURSAL`, `DIM_CANAL`, `DIM_CLIENTE`, `DIM_CUPON` y `DIM_MOTIVO_DEVOLUCION`).

## 3. Diccionario de Tablas del Esquema Estrella

| Tabla | Rol Dimensional | Clave Primaria (PK) | Claves Foráneas (FK) | Atributos y Medidas Principales |
| :--- | :--- | :--- | :--- | :--- |
| `FACT_VENTAS` | Hechos Principal | `linea_id` | `cliente_key`, `producto_key`, `sucursal_venta_key`, `sucursal_entrega_key`, `canal_key`, `fecha_key`, `cupon_key` | `orden_id` (DD), `cantidad`, `precio_lista_total`, `descuento_total`, `venta_neta`, `tipo_precio` (`regular`, `liquidacion`, `promocion`) |
| `FACT_DEVOLUCIONES` | Hechos Auxiliar | `devolucion_key` | `producto_key`, `sucursal_key`, `fecha_key`, `motivo_key`, `linea_id` | `tipo_movimiento` (`devolucion`, `reemplazo`), `importe_devuelto` |
| `FACT_MOVIMIENTO_LEALTAD` | Hechos Auxiliar | `movimiento_key` | `cliente_key`, `fecha_key` | `orden_id`, `puntos_ganados`, `puntos_canjeados`, `tipo_movimiento` |
| `DIM_TIEMPO` | Dimensión | `fecha_key` | — | `fecha`, `anio`, `mes`, `trimestre`, `temporada_comercial` |
| `DIM_PRODUCTO` | Dimensión | `producto_key` | — | `variante_id` (NK), `sku`, `talla`, `color`, `nombre`, `categoria`, `coleccion`, `temporada`, `marca` |
| `DIM_SUCURSAL` | Dimensión (Doble Rol) | `sucursal_key` | — | `sucursal_id` (NK), `nombre`, `ciudad`, `region`, `tipo_tienda` |
| `DIM_CANAL` | Dimensión | `canal_key` | — | `nombre_canal`, `es_online`, `requiere_entrega_linea` |
| `DIM_CLIENTE` | Dimensión | `cliente_key` | — | `cliente_id` (NK), `nivel_lealtad`, `ciudad`, `genero_opcional`, `fecha_alta` |
| `DIM_CUPON` | Dimensión | `cupon_key` | — | `cupon_id` (NK), `tipo`, `valor` |
| `DIM_MOTIVO_DEVOLUCION` | Dimensión | `motivo_key` | — | `descripcion_motivo`, `categoria_motivo` |
