# Proyecto 2: Procesamiento y Análisis Exploratorio de Datos Masivos en BigQuery

**Universidad de San Carlos de Guatemala — Facultad de Ingeniería — Escuela de Ciencias y Sistemas**
**Seminario de Sistemas 2 — SS22S2026 — Grupo 8**

## Integrantes

| Integrante | Responsabilidad |
|---|---|
| Estuardo Santos | Datos, optimización, modelos base y repositorio |
| Pablo *(completar apellido/carné)* | Evaluación de modelos y predicciones |
| Diego *(completar apellido/carné)* | Análisis exploratorio y visualización |

## Estructura del repositorio

```
Proyecto_2/
├── README.md
├── sql/
│   ├── 00_setup.sql                       # dataset propio (US)
│   ├── 01_exploracion_dataset.sql         # conexión y comprensión del dataset
│   ├── 02_calidad_datos.sql               # nulos, outliers, fechas inválidas
│   ├── 03_tablas_optimizadas.sql          # trips_base / trips_opt (partición + clustering)
│   ├── 04_comparacion_bytes.sql           # estándar vs. optimizada
│   ├── 05_tabla_ml.sql                    # tabla limpia + features + split
│   ├── 06_modelos_bqml.sql                # entrenamiento de modelos
│   └── 07_evidencias_split_entrenamiento.sql
├── scripts/run_sql.sh                     # ejecuta un .sql con la CLI bq
└── evidencias/
    ├── capturas/                          # capturas de la consola de BigQuery
    └── salidas/                           # salidas en texto de las consultas
```
*(Pablo y Diego agregan sus scripts `08_…`, `09_…` en `sql/`.)*

---

## 1. Dataset utilizado

- **Fuente:** `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022` (NYC TLC Yellow Taxi, año 2022).
- **Volumen:** **36,256,539 registros** (6.97 GB), de enero a noviembre 2022 (diciembre solo trae 57 filas de un día) — supera el mínimo de 1 millón. *(El enunciado menciona "más de 100 millones", pero el conteo real de esta tabla es el indicado.)*
- **Ubicación:** multi-región `US`; el dataset propio `nyc_taxi_p2` se creó también en `US`.
- **Columnas principales:** `pickup_datetime`, `dropoff_datetime`, `passenger_count`, `trip_distance`, `rate_code`, `payment_type`, `fare_amount`, `tip_amount`, `tolls_amount`, `total_amount`, `pickup_location_id`, `dropoff_location_id`.

### Calidad de datos
Fuente: [`evidencias/salidas/02_calidad_datos.txt`](evidencias/salidas/02_calidad_datos.txt). Total analizado: 36,256,539 filas.

| Problema | Registros | Tratamiento |
|---|---:|---|
| Nulos en `passenger_count` y `rate_code` | 1,241,840 (3.4 %) | Excluidos en `ml_trips_clean` (coinciden con `payment_type = 0`) |
| Pickup fuera de 2022 (años 2001–2021 y 2023) | 556 | Excluidos al crear `trips_base` |
| `dropoff < pickup` | 13,509 | Excluidos (duración 1–180 min) |
| Duración > 3 h / < 1 min | 45,611 / 496,521 | Excluidos |
| Distancia ≤ 0 / > 100 mi | 511,442 / 1,384 | Excluidos (0.1–100 mi) |
| Tarifa ≤ 0 / > 200 USD | 241,621 / 6,550 | Excluidos (2.5–200 USD) |
| Pasajeros 0 / > 6 | 703,119 / 380 | Excluidos (1–6) |
| Propina negativa / mayor que la tarifa | 3,135 / 60,720 | Excluidos |
| Propina en efectivo (`payment_type = 2`: 99.98 % con propina 0) | 7,102,477 | Solo se modela `payment_type = 1` (tarjeta) |

**Outliers (p99 / máximo):** distancia 20.2 mi / 389,678 mi; tarifa 60.07 / 401,092 USD; duración 66 min / 10.3 millones de min. Los máximos son claramente errores de captura.

**Resultado de la limpieza:** de 36,255,983 filas de 2022 quedan **26,095,456 (71.98 %)** en `ml_trips_clean`: 21,084,528 en `train`, 2,653,483 en `eval` y 2,357,445 en `new_records`.

## 2. Transformaciones realizadas

1. `trips_base`: copia de la tabla pública restringida a pickup en 2022 (sin optimizar).
2. `trips_opt`: misma información, optimizada (sección 3).
3. `ml_trips_clean`: tipado, limpieza y variables derivadas (sección 5).
4. `ml_new_records`: noviembre 2022 reservado para predicciones.

## 3. Técnicas de optimización aplicadas

| Técnica | Definición | Justificación |
|---|---|---|
| Partición | `PARTITION BY DATE(pickup_datetime)` | Las consultas temporales filtran por día/mes; solo se leen las particiones necesarias. |
| Clustering | `CLUSTER BY pickup_location_id, dropoff_location_id` | Los filtros y agrupaciones por zona son frecuentes; ordena físicamente los datos y omite bloques. |

### Comparación de desempeño (estándar vs. optimizada)
Evidencia: capturas [11](evidencias/capturas/11_comparacion_1A_publica.png) a [17](evidencias/capturas/17_resumen_comparacion.png) (consola de BigQuery, caché desactivada, `cache_hit = false`).

**Escenario 1 — junio 2022 + zonas JFK/LGA (filtra por partición y clustering):**

| Tabla | MB procesados | MB facturados | Tiempo (ms) | Slot-ms |
|---|---:|---:|---:|---:|
| Pública | 1,550.1 | 1,551.0 | 363 | 3,149 |
| `trips_base` (sin optimizar) | 1,550.0 | 1,551.0 | 413 | 16,292 |
| **`trips_opt`** | **124.9** | **125.0** | **293** | **770** |

→ **Reducción de 91.9 % en bytes procesados** (12.4× menos) y de 95 % en slot-ms respecto a `trips_base`.

**Escenario 2 — solo zona 161 (todo el año; aísla el clustering):**

| Tabla | MB procesados | MB facturados | Tiempo (ms) | Slot-ms |
|---|---:|---:|---:|---:|
| Pública | 996.8 | 997.0 | 390 | 5,390 |
| `trips_base` | 996.8 | 997.0 | 409 | 6,327 |
| `trips_opt` | 900.4 | 901.0 | 440 | 28,603 |

→ Reducción de solo **9.7 %** en bytes, con más tiempo de cómputo (slot-ms) que la tabla sin optimizar.

**Conclusión:** la **partición por fecha** es la técnica de mayor impacto: al filtrar un mes solo se leen ~30 de las 335 particiones. El **clustering aporta poco por sí solo** en este dataset: cada partición diaria es pequeña (~20 MB) y BigQuery solo omite bloques dentro de cada partición; es probable que, al ser una zona muy frecuente, casi todos los bloques contengan la zona buscada. Su beneficio es mayor combinado con el filtro de fecha. Los tiempos (290–440 ms) son demasiado cortos y variables para comparar; la métrica relevante es bytes procesados, que es lo que se factura.

## 4. Planteamiento del problema de ML

Predecir la **propina** de un viaje pagado con tarjeta:
- **Regresión:** ¿cuántos USD de propina dejará el pasajero? (`tip_amount`)
- **Clasificación:** ¿será una propina alta, es decir ≥ 20 % de la tarifa? (`high_tip`)

## 5. Ingeniería de características (`ml_trips_clean`)

| Variable derivada | Cálculo | Justificación |
|---|---|---|
| `pickup_hour` | Hora de recogida (0–23) | La propina varía por franja horaria (noche/madrugada vs. día). |
| `pickup_dow` | Día de la semana (1–7) | Patrones distintos entre semana y fin de semana. |
| `is_weekend` | Sábado o domingo | Resume el comportamiento de ocio vs. trabajo. |
| `is_rush_hour` | L–V 7–9 h y 16–19 h | Viajes laborales con tarifas y propinas distintas. |
| `trip_duration_min` | `dropoff − pickup` en minutos | Los viajes largos en tiempo tienen mayor tarifa/propina. |
| `avg_speed_mph` | distancia / horas | Aproxima congestión; también sirve como filtro de errores. |
| `fare_per_mile` | tarifa / distancia | Captura recargos y tráfico (distingue viajes cortos caros). |
| `is_airport` | Tarifa JFK/Newark o zona 1/132/138 | Los viajes al aeropuerto tienen comportamiento de propina propio. |
| `has_tolls` | `tolls_amount > 0` | Indica uso de autopistas/puentes. |
| `tip_pct` | tip / fare | Base para construir `high_tip` (**no** es feature). |
| `high_tip` | `tip_pct ≥ 0.20` | Etiqueta de clasificación (20 % es la propina estándar en NYC). |

## 6. Variables de entrada, salida y objetivo

| Modelo | Tipo | Objetivo (label) | Entradas (features) |
|---|---|---|---|
| **M1** `model_tip_linear` | `LINEAR_REG` | `tip_amount` | `pickup_hour`, `pickup_dow`, `is_weekend`, `is_rush_hour`, `pickup_location_id`, `dropoff_location_id`, `passenger_count`, `rate_code_id`, `is_airport`, `trip_distance`, `trip_duration_min`, `avg_speed_mph`, `fare_amount`, `fare_per_mile`, `tolls_amount`, `has_tolls` |
| **M2** `model_tip_logistic` | `LOGISTIC_REG` | `high_tip` | Las mismas que M1 |
| **M3** `model_tip_boosted` | `BOOSTED_TREE_REGRESSOR` | `tip_amount` | Las mismas que M1 (variante con otro algoritmo e hiperparámetros) |

**Excluidas a propósito:** `tip_amount`/`tip_pct`/`high_tip` (son el objetivo), `total_amount` (incluye la propina), `dropoff_datetime`, `pickup_month`, `pickup_date`.

## 7. Prevención de *data leakage* y split de datos

1. **Fuga por variables:** ninguna feature contiene información de la propina (`total_amount` y `tip_pct` excluidas). `fare_amount` sí se usa porque se conoce al finalizar el viaje, antes de que el pasajero decida la propina.
2. **Split temporal, no aleatorio:** un split aleatorio mezclaría días futuros en el entrenamiento y sobrestimaría el desempeño. Se usa:

| Conjunto | Periodo | Uso |
|---|---|---|
| `train` | ene–sep 2022 | Entrenamiento |
| `eval` | oct 2022 | Evaluación (`is_eval = TRUE`) |
| `new_records` | nov 2022 | Nunca visto: `ML.PREDICT` y Rolling Forecast |

> El dataset público solo contiene datos de enero a noviembre 2022 (diciembre trae únicamente 57 filas de un día), por lo que el split se desplazó un mes.

3. **`data_split_method = 'CUSTOM'`** con la columna booleana `is_eval` en M1 y M2 → ambos se evalúan sobre **exactamente el mismo** conjunto (comparación justa).
4. **`data_split_eval_fraction = 0.2` con `data_split_method = 'SEQ'`** sobre `pickup_datetime` en M3 → el 80 % más antiguo entrena y el 20 % más reciente evalúa. Se usa este método porque `data_split_eval_fraction` no aplica con `CUSTOM`.
5. `pickup_month` se excluye: con split temporal, octubre no existe en `train` y el mes no generaliza.
6. Comprobación: `07_evidencias_split_entrenamiento.sql` verifica que los rangos de fechas no se solapan y qué features usó cada modelo.

## 8. Modelos entrenados en BigQuery ML
Scripts: [`sql/06_modelos_bqml.sql`](sql/06_modelos_bqml.sql). Evidencias: capturas [22](evidencias/capturas/22a_detalles_linear.png) a [25a](evidencias/capturas/25a_training_info_boosted.png)/[25b](evidencias/capturas/25b_training_info_logistic.png)/[25c](evidencias/capturas/25c_training_info_linear.png).

| Modelo | Algoritmo | Split | Iteraciones | Loss entrenamiento | Loss evaluación |
|---|---|---|---:|---:|---:|
| M1 `model_tip_linear` | `LINEAR_REG` (`l2_reg = 0.1`) | `CUSTOM` (`is_eval`) | 1 | 2.336 | 2.474 |
| M2 `model_tip_logistic` | `LOGISTIC_REG` (`l2_reg = 0.1`, `auto_class_weights`) | `CUSTOM` (`is_eval`) | 2 | 0.687 | 0.690 |
| M3 `model_tip_boosted` | `BOOSTED_TREE_REGRESSOR` (`max_tree_depth = 6`, `learn_rate = 0.1`, `subsample = 0.8`) | `SEQ` + `data_split_eval_fraction = 0.2`, muestra 25 % | 20 | 1.584 | 1.682 |

*Loss = error cuadrático medio en M1 y M3; log-loss en M2. Los valores no son comparables entre algoritmos distintos; la comparación con RMSE, ROC-AUC y matriz de confusión se hace en la sección 9.*

## 9. Evaluación y comparación de modelos *(sección de Pablo)*
*(Pendiente: ML.EVALUATE, métricas, ajuste de hiperparámetros, modelo elegido, ML.PREDICT y Rolling Forecast.)*

## 10. Hallazgos relevantes *(Diego)*
Scripts exploratorios comentados: [`12_eda_temporal.sql`](sql/12_eda_temporal.sql) (hora, día, mes, mapa de calor, días extremos), [`13_eda_pago_zonas.sql`](sql/13_eda_pago_zonas.sql) (tipo de pago, `rate_code`, zonas, rutas, aeropuertos), [`14_eda_tarifas_propinas.sql`](sql/14_eda_tarifas_propinas.sql) (distribuciones, correlaciones, propina por distancia/hora/zona) y [`15_tablas_dashboard.sql`](sql/15_tablas_dashboard.sql) (tablas agregadas para el tablero). Usan agregaciones (`COUNT`, `AVG`, `SUM`, `CORR`, `APPROX_QUANTILES`), funciones temporales (`EXTRACT`, `DATE_TRUNC`, `FORMAT_TIMESTAMP`, `TIMESTAMP_DIFF`), funciones de ventana (`LAG`, `RANK`, media móvil), `PIVOT`, `QUALIFY`, `CASE` y `JOIN` con el catálogo de zonas `taxi_zone_geom`. Todas consultan `trips_opt` o `ml_trips_clean` filtrando por fecha para aprovechar la partición.

Los hallazgos **H1–H5** ya están respaldados por las salidas de Estuardo ([`01_exploracion_dataset.txt`](evidencias/salidas/01_exploracion_dataset.txt), [`02_calidad_datos.txt`](evidencias/salidas/02_calidad_datos.txt)). Los **H6–H10** dependen de los scripts 12–14: la consulta que los sustenta y su captura se indican en cada uno, y las cifras marcadas con `—` se completan al ejecutarlos.

### Temporales
- **H1 — Enero es el mes más bajo y la demanda se recupera en primavera.** Enero 2022 tuvo 2,463,900 viajes (≈ 79.5 mil/día) frente a ≈ 120 mil/día en abril y 118.6 mil/día en octubre, el máximo absoluto con 3,675,372 viajes. Es decir, **+49 %** entre enero y octubre. Coincide con la ola de Ómicron y el invierno de enero 2022.
- **H2 — Bache de verano.** Julio–septiembre baja a ≈ 102–106 mil viajes/día (julio −10.8 % respecto a junio). Se explica por vacaciones y menos desplazamientos laborales y de oficina en Manhattan. La demanda repunta en octubre.
- **H6 — Horas pico y día de la semana** (consultas 12.2–12.4, capturas 41–43). Picos de viajes: — h entre semana y — h los fines de semana. El tráfico baja la velocidad promedio a — mph en la hora pico, frente a — mph de madrugada. Día con más viajes por día: —.

### Categóricas (tipo de pago y tarifa)
- **H3 — La tarjeta domina y la propina en efectivo no existe en los datos.** Tarjeta 75.94 % de los viajes, efectivo 19.59 %, sin dato 3.43 %, disputa 0.57 % y sin cargo 0.48 %. En efectivo, el **99.98 %** de los viajes tiene propina = 0: no es que no se dé propina, sino que **no se registra**. Por eso todo el análisis de propinas y los modelos usan solo pagos con tarjeta. Con tarjeta, solo el 3.97 % deja propina 0 y el promedio es 3.41 USD.
- **H4 — La tarifa estándar es el 91.3 % de los viajes.** Le siguen JFK con tarifa plana (3.76 %), negociada (0.78 %), código desconocido 99 (0.33 %), Newark (0.27 %) y Nassau/Westchester (0.13 %). Los viajes al aeropuerto son pocos, pero tienen la tarifa y la propina más altas (consulta 13.7, captura 50: propina promedio JFK — USD vs. resto — USD).

### Económicas
- **H5 — Los viajes típicos son cortos y baratos, con colas extremas que son errores.** Mediana de tarifa 10 USD, propina 2.16 USD, distancia 1.9 mi y duración 12.2 min. El percentil 99 es 60 USD y 20 mi, pero los máximos (401,092 USD, 389,678 mi, 10 millones de minutos) son errores de captura; por eso se aplicaron los filtros de la sección 1.
- **H7 — La propina con tarjeta se concentra en los botones sugeridos** (consulta 14.2, captura 52). — % de los viajes queda entre 20–25 % de la tarifa y — % entre 25–35 %. Esto explica por qué el modelo de clasificación `high_tip` tiene poco poder predictivo (sección 9.3): el porcentaje depende sobre todo del botón que elige el pasajero, no del viaje.
- **H8 — El monto de la propina sigue a la tarifa, pero el porcentaje no** (consultas 14.3–14.4, capturas 53–54). Correlación propina–tarifa = —, propina–distancia = —, y % de propina–tarifa = —. Por eso `fare_amount`, `trip_distance` y `trip_duration_min` son las features más fuertes del regresor.

### Geográficas
- **H9 — La demanda se concentra en Manhattan** (consultas 13.4–13.5, capturas 48–49). Las 15 zonas de origen con más viajes acumulan — % del total. El — % de los viajes empieza y termina en Manhattan. La ruta más frecuente es —.
- **H10 — Zonas de mayor propina** (consulta 14.7, captura 56). Las zonas con más % de propina son —; los aeropuertos destacan en monto (USD) por la distancia, no en porcentaje.

## 11. Informe visual
**Enlace al tablero de Looker Studio:** *(pegar aquí el enlace público al crear el tablero)*

Diseño, fuentes y pasos para armarlo: [`informe_visual/GUIA_TABLERO.md`](informe_visual/GUIA_TABLERO.md). Resumen:

| Página | Visualizaciones | Fuentes |
|---|---|---|
| 1. Exploración temporal y de pago | V1 serie diaria de viajes y propina · V2 mapa de calor hora × día · V3 tipo de pago por mes | `dash_diario`, `dash_hora_dia`, `dash_pago_mensual` |
| 2. Zonas, tarifas y propinas | V4 mapa coroplético por zona · V5 top zonas · V6 propina vs. distancia | `dash_zonas`, `dash_distancia_propina` |
| 3. Modelos y predicciones | P1 real vs. predicho (nov) · P2 **Rolling Forecast** W1/W2 boosted vs. ARIMA · P3 error por ventana · P4 comparación de modelos · P5 curva ROC · P6 viajes hipotéticos | `pred_diaria_nov`, `rolling_forecast_*`, `eval_*`, `pred_viajes_hipoteticos` |

## 12. Índice de evidencias (`evidencias/capturas/`)

| Tema | Capturas |
|---|---|
| Esquema, conteo y calidad del dataset | [01](evidencias/capturas/01_esquema_dataset.png), [02](evidencias/capturas/02_conteo_registros.png), [03](evidencias/capturas/03_calidad_nulos.png), [04](evidencias/capturas/04_calidad_invalidos.png), [05](evidencias/capturas/05_outliers_percentiles.png), [06](evidencias/capturas/06_propina_efectivo.png) |
| Tablas, particiones y clustering | [07](evidencias/capturas/07_tablas_creadas.png), [08](evidencias/capturas/08_particiones.png), [09](evidencias/capturas/09_clustering.png), [10](evidencias/capturas/10_detalles_tabla_opt.png), [10b](evidencias/capturas/10b_detalles_tabla_base.png) |
| Comparación estándar vs. optimizada | [11](evidencias/capturas/11_comparacion_1A_publica.png), [12](evidencias/capturas/12_comparacion_1B_base.png), [13](evidencias/capturas/13_comparacion_1C_opt.png), [14](evidencias/capturas/14_comparacion_2A_publica.png), [15](evidencias/capturas/15_comparacion_2B_base.png), [16](evidencias/capturas/16_comparacion_2C_opt.png), [17 (resumen)](evidencias/capturas/17_resumen_comparacion.png) |
| Tabla ML y split | [18](evidencias/capturas/18_tabla_ml_filas.png), [19](evidencias/capturas/19_split_temporal.png), [20](evidencias/capturas/20_split_sin_solapamiento.png), [21a](evidencias/capturas/21a_features_modelos.png)/[21b](evidencias/capturas/21b_features_modelos.png) |
| Entrenamiento de modelos | [22a](evidencias/capturas/22a_detalles_linear.png)/[22b](evidencias/capturas/22b_entrenamiento_linear.png), [23a](evidencias/capturas/23a_detalles_logistic.png)/[23b](evidencias/capturas/23b_entrenamiento_logistic.png), [24a](evidencias/capturas/24a_detalles_boosted.png)/[24b](evidencias/capturas/24b_entrenamiento_boosted.png), [25a](evidencias/capturas/25a_training_info_boosted.png)/[25b](evidencias/capturas/25b_training_info_logistic.png)/[25c](evidencias/capturas/25c_training_info_linear.png) |

Salidas en texto: [`evidencias/salidas/`](evidencias/salidas/).

## 13. Cómo reproducir
1. Crear un proyecto de Google Cloud con facturación activa y autenticar la CLI (`gcloud auth login`, `gcloud config set project <ID>`).
2. Reemplazar `ss22s2026-g8-proyecto2` por el ID del proyecto en `sql/*.sql`.
3. Ejecutar en orden con `./scripts/run_sql.sh sql/<archivo>.sql`: `00 → 03 → 05 → 06`. Los scripts `01`, `02`, `04` y `07` son de exploración/evidencia y se ejecutan por bloques en la consola de BigQuery (para `04`, con la caché de consultas desactivada).
4. El dataset debe crearse en la región `US`, igual que el dataset público.
