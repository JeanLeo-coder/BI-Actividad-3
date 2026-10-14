# Repositorio Unidad 3 — Consultas SQL Empresariales con Apoyo de IA (Moda Urbana · Equipo 3)

**Universidad Autónoma de Nuevo León (UANL) · Facultad de Ingeniería Mecánica y Eléctrica (FIME)**  
**Materia:** Analítica e Inteligencia de Negocios · **Docente:** Prof. Miguel Ángel Gómez Marroquín  
**Integrantes del Equipo 3:**
- Antonio André Martínez Martínez — `2094967`
- Erick Morán Guillén — `2103747`
- Jean Leo Ramírez — `2102785`

## Estructura del Repositorio

- `01_modelo_unidad_2/`: Diagrama estrella de la Unidad 2 (`esquema_estrella_unidad_2.png`), modelo conceptual y lógico, diccionario de tablas (`01_modelo_y_diccionario.md`) y Ficha de Decisiones de Negocio (`02_ficha_decisiones_negocio.md`).
- `02_ddl_y_datos/`: Script DDL ejecutable en MySQL 8.0 (`01_ddl_moda_urbana.sql`) y carga reproducible de 1,500 filas en `FACT_VENTAS` + dimensiones + devoluciones para Q1 y Q2 2026 (`02_carga_datos_simulados.sql`).
- `03_prompts_ia/`: Prompt inicial completo, respuesta original de la IA y tabla de registro de decisiones y correcciones del equipo (`01_prompt_inicial_y_respuesta_ia.md`).
- `04_consultas_sql/`: Versión inicial propuesta por la IA (`01_consulta_inicial_ia.sql`) y versión final validada por el equipo (`02_consulta_final_validada.sql`).
- `05_validacion_y_explain/`: Consultas de control de grano y totales (`01_validacion_conteos_control.sql`), reproducción y solución del Error 1055 (`02_error_1055_depuracion.sql`) y optimización con `EXPLAIN` e índices compuestos (`03_optimizacion_explain.sql`).
- `06_stored_procedure/`: Creación y llamada de prueba del procedimiento almacenado `sp_top_productos_rentables_region` (`01_sp_reporte_rentabilidad_region.sql`).
- `07_conclusion/`: Síntesis de hallazgos de negocio, limitaciones del modelo y conclusiones individuales (`01_conclusion_equipo_3.md`).
