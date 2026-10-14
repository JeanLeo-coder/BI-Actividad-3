-- ============================================================================
-- ENTREGABLE 2 (PARTE A): SCRIPT DDL DEL ESQUEMA ESTRELLA — MODA URBANA
-- Materia: Analítica e Inteligencia de Negocios (Unidad 3)
-- Equipo 3: Antonio André Martínez (2094967), Erick Morán (2103747), Jean Leo Ramírez (2102785)
-- Motor: MySQL 8.0
-- Nota de continuidad U2 -> U3: Conserva íntegramente las 10 tablas diseñadas en la
-- Actividad 2, corrigiendo únicamente la coma final tras CONSTRAINT chk_tipo_precio.
-- ============================================================================

DROP DATABASE IF EXISTS moda_urbana_dm;
CREATE DATABASE moda_urbana_dm CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE moda_urbana_dm;

-- 1) DIM_TIEMPO: Propia del Data Mart para analizar por trimestre y temporada comercial.
CREATE TABLE DIM_TIEMPO (
    fecha_key INT PRIMARY KEY,
    fecha DATE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL,
    trimestre INT NOT NULL,
    temporada_comercial VARCHAR(30) NOT NULL -- "Primavera-Verano", "Otoño-Invierno"
) ENGINE=InnoDB;

-- 2) DIM_CANAL: Permite analizar por canal de venta y modalidad de entrega.
CREATE TABLE DIM_CANAL (
    canal_key INT PRIMARY KEY,
    nombre_canal VARCHAR(30) NOT NULL, -- "Tienda Física", "E-Commerce", "App Móvil", "Click & Collect"
    es_online BOOLEAN NOT NULL,
    requiere_entrega_linea BOOLEAN NOT NULL -- true si requiere envío a domicilio, false si es Click & Collect / tienda
) ENGINE=InnoDB;

-- 3) DIM_CLIENTE: Información de lealtad y ubicación del consumidor final.
CREATE TABLE DIM_CLIENTE (
    cliente_key INT PRIMARY KEY,
    cliente_id INT NOT NULL, -- ID natural de origen del cliente
    nivel_lealtad VARCHAR(30),
    ciudad VARCHAR(30) NOT NULL,
    genero_opcional VARCHAR(20),
    fecha_alta DATE NOT NULL
) ENGINE=InnoDB;

-- 4) DIM_SUCURSAL: Referenciada dos veces en FACT_VENTAS (venta y entrega) para distinguir online vs Click & Collect.
CREATE TABLE DIM_SUCURSAL (
    sucursal_key INT PRIMARY KEY,
    sucursal_id INT NOT NULL, -- ID natural de origen de la sucursal
    nombre VARCHAR(30) NOT NULL,
    ciudad VARCHAR(30) NOT NULL,
    region VARCHAR(30) NOT NULL, -- "Norte", "Centro", "Occidente", "Sur"
    tipo_tienda VARCHAR(30) NOT NULL
) ENGINE=InnoDB;

-- 5) DIM_PRODUCTO: Desnormalización de Variantes y Productos. Conserva el nivel de variante (SKU, talla, color).
CREATE TABLE DIM_PRODUCTO (
    producto_key INT PRIMARY KEY,
    variante_id INT NOT NULL, -- ID natural de origen de la variante
    sku VARCHAR(30) NOT NULL,
    talla VARCHAR(10) NOT NULL,
    color VARCHAR(30) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    categoria VARCHAR(60) NOT NULL,
    coleccion VARCHAR(60) NOT NULL,
    temporada VARCHAR(30) NOT NULL,
    marca VARCHAR(30) NOT NULL
) ENGINE=InnoDB;

-- 6) DIM_CUPON: Catálogo de instrumentos promocionales aplicados.
CREATE TABLE DIM_CUPON (
    cupon_key INT PRIMARY KEY,
    cupon_id INT NOT NULL, -- ID natural de origen del cupón
    tipo VARCHAR(30) NOT NULL,
    valor DECIMAL(10, 2) NOT NULL
) ENGINE=InnoDB;

-- 7) DIM_MOTIVO_DEVOLUCION: Catálogo de causas de retorno de mercancía.
CREATE TABLE DIM_MOTIVO_DEVOLUCION (
    motivo_key INT PRIMARY KEY,
    descripcion_motivo VARCHAR(100) NOT NULL,
    categoria_motivo VARCHAR(30) NOT NULL
) ENGINE=InnoDB;

-- 8) FACT_VENTAS: Tabla de hechos central.
-- Grano: Una fila = una variante de producto vendida dentro de una línea de una orden de compra.
CREATE TABLE FACT_VENTAS (
    linea_id INT PRIMARY KEY,
    orden_id INT NOT NULL,
    cliente_key INT NOT NULL,
    producto_key INT NOT NULL,
    sucursal_venta_key INT NOT NULL,
    sucursal_entrega_key INT NOT NULL,
    canal_key INT NOT NULL,
    fecha_key INT NOT NULL,
    cupon_key INT NULL,
    cantidad INT NOT NULL,
    precio_lista_total DECIMAL(10, 2) NOT NULL, -- precio_lista * cantidad
    descuento_total DECIMAL(10, 2) NOT NULL,    -- descuento * cantidad
    venta_neta DECIMAL(10, 2) NOT NULL,         -- precio_venta * cantidad
    tipo_precio VARCHAR(30) NOT NULL,           -- 'regular', 'liquidacion', 'promocion'
    FOREIGN KEY (cliente_key) REFERENCES DIM_CLIENTE(cliente_key),
    FOREIGN KEY (producto_key) REFERENCES DIM_PRODUCTO(producto_key),
    FOREIGN KEY (sucursal_venta_key) REFERENCES DIM_SUCURSAL(sucursal_key),
    FOREIGN KEY (sucursal_entrega_key) REFERENCES DIM_SUCURSAL(sucursal_key),
    FOREIGN KEY (canal_key) REFERENCES DIM_CANAL(canal_key),
    FOREIGN KEY (fecha_key) REFERENCES DIM_TIEMPO(fecha_key),
    FOREIGN KEY (cupon_key) REFERENCES DIM_CUPON(cupon_key),
    CONSTRAINT chk_tipo_precio CHECK (tipo_precio IN ('regular', 'liquidacion', 'promocion'))
) ENGINE=InnoDB;

-- 9) FACT_MOVIMIENTO_LEALTAD: Tabla de hechos para acumulación y redención de puntos.
CREATE TABLE FACT_MOVIMIENTO_LEALTAD (
    movimiento_key INT PRIMARY KEY,
    cliente_key INT NOT NULL,
    fecha_key INT NOT NULL,
    orden_id INT NOT NULL,
    puntos_ganados INT NOT NULL,
    puntos_canjeados INT NOT NULL,
    tipo_movimiento VARCHAR(30) NOT NULL, -- "ganancia", "canje", "ajuste"
    FOREIGN KEY (cliente_key) REFERENCES DIM_CLIENTE(cliente_key),
    FOREIGN KEY (fecha_key) REFERENCES DIM_TIEMPO(fecha_key)
) ENGINE=InnoDB;

-- 10) FACT_DEVOLUCIONES: Tabla de hechos de retornos parciales o totales referenciados por linea_id.
CREATE TABLE FACT_DEVOLUCIONES (
    devolucion_key INT PRIMARY KEY,
    producto_key INT NOT NULL,
    sucursal_key INT NOT NULL,
    fecha_key INT NOT NULL,
    motivo_key INT NOT NULL,
    linea_id INT NOT NULL,
    tipo_movimiento VARCHAR(30) NOT NULL, -- "devolucion", "reemplazo"
    importe_devuelto DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (producto_key) REFERENCES DIM_PRODUCTO(producto_key),
    FOREIGN KEY (sucursal_key) REFERENCES DIM_SUCURSAL(sucursal_key),
    FOREIGN KEY (fecha_key) REFERENCES DIM_TIEMPO(fecha_key),
    FOREIGN KEY (motivo_key) REFERENCES DIM_MOTIVO_DEVOLUCION(motivo_key),
    FOREIGN KEY (linea_id) REFERENCES FACT_VENTAS(linea_id)
) ENGINE=InnoDB;
