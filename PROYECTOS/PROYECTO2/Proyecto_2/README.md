# Proyecto 2: Procesamiento y Análisis Exploratorio de Datos Masivos en BigQuery

**Universidad de San Carlos de Guatemala — Facultad de Ingeniería — Escuela de Ciencias y Sistemas**
**Seminario de Sistemas 2 — SS22S2026 — Grupo 8**

## Integrantes

| Integrante | Carné | Responsabilidad |
|---|---|---|
| Estuardo Santos | *(completar)* | Datos, optimización, modelos base y repositorio |
| Pablo Alejandro Marroquin Cutz | 202200214 | Evaluación de modelos y predicciones |
| Diego Debroy | 202101923 | Análisis exploratorio, visualización y revisión final |

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
│   ├── 07_evidencias_split_entrenamiento.sql
│   ├── 08_evaluacion_modelos.sql          # ML.EVALUATE, ROC, matriz de confusión   (Pablo)
│   ├── 09_ajuste_hiperparametros.sql      # variantes _v2 y modelo elegido          (Pablo)
│   ├── 10_predicciones.sql                # ML.PREDICT sobre registros nuevos       (Pablo)
│   ├── 11_rolling_forecast.sql            # rolling forecast W1/W2                  (Pablo)
│   ├── 12_eda_temporal.sql                # hora, día, mes                          (Diego)
│   ├── 13_eda_pago_zonas.sql              # tipo de pago, tarifa, zonas, rutas      (Diego)
│   ├── 14_eda_tarifas_propinas.sql        # tarifas y propinas                      (Diego)
│   └── 15_tablas_dashboard.sql            # tablas agregadas para Looker Studio     (Diego)
├── informe_visual/GUIA_TABLERO.md         # diseño y fuentes del tablero
├── scripts/run_sql.sh                     # ejecuta un .sql con la CLI bq
└── evidencias/
    ├── capturas/                          # capturas de la consola de BigQuery
    └── salidas/                           # salidas en texto de las consultas
```

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

## 9. Evaluación y comparación de modelos *(Pablo)*
Scripts: [`08_evaluacion_modelos.sql`](sql/08_evaluacion_modelos.sql), [`09_ajuste_hiperparametros.sql`](sql/09_ajuste_hiperparametros.sql), [`10_predicciones.sql`](sql/10_predicciones.sql), [`11_rolling_forecast.sql`](sql/11_rolling_forecast.sql).

> Los scripts 08–11 se ejecutaron en BigQuery (capturas [`ejec_09`](evidencias/capturas/ejec_09_hiperparametros.png) y [`ejec_11`](evidencias/capturas/ejec_11_rolling_forecast.png)). Los resultados se presentan con los gráficos de la página 3 del tablero ([captura 60](evidencias/capturas/60_tablero_predicciones.png)).

### 9.1 Explicación de los modelos

| Modelo | Algoritmo | Qué hace | Por qué se eligió |
|---|---|---|---|
| **M1** `model_tip_linear` | Regresión lineal con regularización L2 | Calcula la propina como una suma ponderada de las variables. Las categóricas (zona, hora, día, `rate_code`) se convierten en *one-hot*. | Es el modelo base: rápido, fácil de interpretar (cada coeficiente es "USD de propina por unidad") y sirve de referencia para los demás. |
| **M2** `model_tip_logistic` | Regresión logística con `auto_class_weights` | Calcula la probabilidad de que la propina sea ≥ 20 % de la tarifa y la clasifica con un umbral. | Responde una pregunta de negocio distinta (¿el pasajero dará buena propina?) y se evalúa con ROC-AUC y matriz de confusión. |
| **M3** `model_tip_boosted` | *Gradient boosted trees* (XGBoost) | Suma árboles de decisión; cada árbol corrige el error de los anteriores. | Capta relaciones no lineales e interacciones (p. ej., aeropuerto × hora) que la regresión lineal no puede representar. |

### 9.2 Cómo se compara (sin *data leakage*)
- **Mismo conjunto para todos:** los modelos se evalúan con `ML.EVALUATE` sobre **octubre 2022** (`split_set = 'eval'`), que ninguno usó para entrenar. M1/M2 entrenaron con ene–sep (`CUSTOM`). En M3 (`SEQ` 80/20 sobre ene–oct) el corte del 80 % cae a inicios de septiembre, así que octubre completo queda en su parte de evaluación.
- **Selección vs. prueba:** octubre se usa para **elegir** modelo e hiperparámetros; **noviembre** (`ml_new_records`) se usa solo al final para confirmar. Elegir mirando noviembre sería filtrar información del conjunto de prueba.
- **Baseline ingenuo:** predecir siempre la propina media de `train`. Un modelo útil debe tener un RMSE claramente menor.

### 9.3 Métricas

**Pérdida durante el entrenamiento** (`ML.TRAINING_INFO`, sección 8): M1 tuvo MSE de evaluación 2.474 (RMSE ≈ 1.57 USD) sobre octubre y M3 tuvo 1.682 (RMSE ≈ 1.30 USD) sobre su propio 20 % de evaluación (`SEQ`, septiembre–octubre, muestra del 25 %). **No son comparables** porque se miden sobre conjuntos distintos; por eso la comparación justa se hizo con `ML.EVALUATE` de todos los modelos sobre **octubre completo**.

**Regresión — RMSE sobre octubre** (tabla `eval_hiperparametros`, gráfico P4 del tablero, [captura 60](evidencias/capturas/60_tablero_predicciones.png)):

| Modelo | RMSE oct (USD) |
|---|---:|
| **M1 `LINEAR_REG` base** | **≈ 1.57** |
| M3 `BOOSTED_TREE` v2 | ≈ 1.60 |
| M1 `LINEAR_REG` v2 | ≈ 1.61 |
| M3 `BOOSTED_TREE` base | ≈ 1.66 |

Los cuatro quedan en un rango estrecho (≈ 1.57–1.66 USD, diferencia < 6 %), y el **modelo lineal base tiene el menor error**. El boosted base, que parecía mejor durante el entrenamiento, es el peor en octubre: su evaluación interna fue optimista porque se calculó sobre otro periodo y con solo el 25 % de los datos.

**Clasificación — curva ROC de M2** (tabla `eval_roc_logistic`, gráfico P5): los puntos (tasa de falsos positivos, recall) por umbral son ≈ (0.59, 0.71), (0.87, 0.92) y (0.91, 0.95), además de (0, 0) y (1, 1). El área bajo esa curva, calculada por trapecios, da **ROC-AUC ≈ 0.56**, apenas por encima de un clasificador al azar (0.5). Coincide con la log-loss de entrenamiento (0.690 ≈ ln 2 = 0.693): para detectar el 71 % de las propinas altas hay que aceptar un 59 % de falsos positivos.

*Los valores marcados con ≈ se leyeron de los gráficos del tablero; las cifras exactas están en las tablas `eval_regresion`, `eval_clasificacion`, `eval_hiperparametros` y `eval_roc_logistic` del dataset `nyc_taxi_p2`.*

### 9.4 Ajuste de hiperparámetros
Cada modelo tiene una variante `_v2` que solo cambia hiperparámetros (mismas features, split y datos). La comparación sobre octubre está en la tabla `eval_hiperparametros` (gráfico P4).

| Modelo | Base | Variante v2 | Hipótesis | Resultado (RMSE oct) |
|---|---|---|---|---|
| M1 lineal | `l2_reg = 0.1` | `l1_reg = 0.5`, `l2_reg = 1.0` | L1 elimina coeficientes de zonas poco frecuentes (~260 categorías) y reduce el sobreajuste. | base ≈ 1.57 / v2 ≈ 1.61: más regularización **empeora** un poco; el modelo base no estaba sobreajustado. |
| M2 logística | `l2_reg = 0.1`, `auto_class_weights = TRUE` | `l2_reg = 1.0`, sin pesos de clase | Sin pesos sube la *accuracy*, pero baja el *recall* de la clase minoritaria. | No aplica RMSE (P4 no la grafica); la base tiene ROC-AUC ≈ 0.56, así que ningún ajuste de regularización puede compensar que las variables casi no explican el % de propina. |
| M3 boosted | `depth = 6`, `learn_rate = 0.1`, ≤ 50 iter. | `depth = 10`, `learn_rate = 0.05`, ≤ 100 iter., `l2_reg = 1`, `colsample_bytree = 0.8` | Árboles más profundos captan más interacciones; la tasa menor y la regularización evitan el sobreajuste. | base ≈ 1.66 / v2 ≈ 1.60: **mejora ≈ 4 %**, pero sigue sin superar al lineal base. |

### 9.5 Modelo elegido y justificación
- **Regresión: se elige M1 `LINEAR_REG` base.** (1) Tiene el menor RMSE en octubre (≈ 1.57 USD), el conjunto de selección. (2) Es el más simple: entrena con todos los datos en una iteración y cada coeficiente se interpreta directamente en USD. (3) Los árboles, incluso ajustados, no lo superan: la propina con tarjeta es casi proporcional a la tarifa, una relación lineal que no necesita interacciones. Las predicciones de M1 y M3 sobre viajes nuevos casi coinciden (sección 9.6), lo que confirma esa estructura.
- **Clasificación:** M2 se mantiene como modelo complementario. Con ROC-AUC ≈ 0.56, su valor está en el hallazgo: **el porcentaje de propina es poco predecible** con estas variables, a diferencia del monto en USD, que sí sigue a la tarifa.

### 9.6 Predicciones sobre registros nuevos (`ML.PREDICT`)
- **`pred_nuevos_registros`** (2,357,445 viajes de noviembre, particionada por fecha): por cada viaje guarda la propina real, `pred_tip_linear`, `pred_tip_boosted`, `pred_high_tip`, `prob_high_tip` y el error de cada regresor. Las predicciones negativas se recortan a 0.
- **`pred_diaria_nov`:** agregado diario real vs. predicho (gráfico P1). En **Thanksgiving (24-nov)** la propina total real fue ≈ 146 mil USD; M1 predijo ≈ 144.5 mil (error ≈ −1 %) y M3 ≈ 138 mil (≈ −5.5 %).
- **`pred_viajes_hipoteticos`:** 5 viajes escritos a mano, que no existen en el dataset (gráfico P6):

| Escenario | Tarifa (USD) | Propina M1 | Propina M3 | % propina (M1) | Prob. propina alta (M2) |
|---|---:|---:|---:|---:|---:|
| JFK → Midtown, viernes 18 h | 52.0 | 11.48 | 11.16 | 22 % | 0.69 |
| LaGuardia → East Village, domingo 15 h | 31.0 | 7.57 | 7.54 | 24 % | 0.77 |
| East Village → Times Sq, sábado 1 h | 12.5 | 2.63 | 2.66 | 21 % | 0.80 |
| Midtown → Upper East Side, martes 9 h | 11.5 | 2.57 | 2.59 | 22 % | 0.82 |
| Viaje corto en Midtown, miércoles 13 h | 5.5 | 2.07 | 1.69 | 38 % | 0.83 |

El monto predicho crece con la tarifa y los dos regresores difieren en ≤ 0.4 USD. En cambio, M2 da probabilidades parecidas (0.69–0.83) a viajes muy distintos: no logra separar quién deja propina alta.

### 9.7 Comparación de 2 predicciones — *Rolling Forecast*
Se valida con **origen móvil (ventana expansiva)**: en cada origen se reentrena solo con el pasado y se predice el mes siguiente.

| Ventana | Entrena con | Predice | Modelos |
|---|---|---|---|
| **W1** | ene–sep 2022 | oct 2022 | `rf_boosted_w1`, `rf_arima_w1` |
| **W2** | ene–oct 2022 | nov 2022 | `rf_boosted_w2`, `rf_arima_w2` |

En cada ventana se comparan **dos predicciones** de la propina total diaria:
1. **Boosted por viaje agregado:** predice la propina de cada viaje con sus features y suma por día.
2. **ARIMA_PLUS:** pronostica la serie diaria solo con su historial (tendencia, estacionalidad semanal y feriados de EE. UU.), con un intervalo de confianza del 90 %.

**Resultados** (tablas `rolling_forecast_diario` y `rolling_forecast_resumen`, gráficos P2 y P3):
- En días normales, las dos predicciones siguen el ciclo semanal de la serie real (≈ 200–300 mil USD de propina diaria).
- **Thanksgiving (24-nov, ventana W2)** marca la diferencia: la propina real fue ≈ 148 mil USD. El boosted predijo ≈ 131 mil (≈ −11 %), mientras que ARIMA predijo ≈ 331 mil, con un intervalo del 90 % de ≈ 255–403 mil que **no contiene el valor real**. ARIMA no tenía ningún Thanksgiving en su historial de entrenamiento (ene–oct) para aprender ese efecto. El boosted sí reacciona, porque predice a partir de los viajes que realmente ocurrieron ese día.
- En la tabla P3, el MAPE de ARIMA es mayor en W2 (noviembre) que en W1 (octubre), por el efecto del feriado. El boosted mantiene un error parecido en ambas ventanas: reentrenar con un mes más de datos no lo degrada.

**Conclusión:** para estimar lo que pasó con los viajes de un día, el modelo por viaje es más robusto. ARIMA sirve para planificar *antes* de que ocurran los viajes, pero falla en eventos que no vio en su historial.

## 10. Hallazgos relevantes *(Diego)*
Scripts exploratorios comentados: [`12_eda_temporal.sql`](sql/12_eda_temporal.sql) (hora, día, mes, mapa de calor, días extremos), [`13_eda_pago_zonas.sql`](sql/13_eda_pago_zonas.sql) (tipo de pago, `rate_code`, zonas, rutas, aeropuertos), [`14_eda_tarifas_propinas.sql`](sql/14_eda_tarifas_propinas.sql) (distribuciones, correlaciones, propina por distancia/hora/zona) y [`15_tablas_dashboard.sql`](sql/15_tablas_dashboard.sql) (tablas agregadas para el tablero). Usan agregaciones (`COUNT`, `AVG`, `SUM`, `CORR`, `APPROX_QUANTILES`), funciones temporales (`EXTRACT`, `DATE_TRUNC`, `FORMAT_TIMESTAMP`, `TIMESTAMP_DIFF`), funciones de ventana (`LAG`, `RANK`, media móvil), `PIVOT`, `QUALIFY`, `CASE` y `JOIN` con el catálogo de zonas `taxi_zone_geom`. Todas consultan `trips_opt` o `ml_trips_clean` filtrando por fecha para aprovechar la partición.

Los hallazgos **H1–H5** se basan en las salidas de [`01_exploracion_dataset.txt`](evidencias/salidas/01_exploracion_dataset.txt) y [`02_calidad_datos.txt`](evidencias/salidas/02_calidad_datos.txt); los **H6–H10**, en los scripts 12–15 ejecutados (capturas [`ejec_12`](evidencias/capturas/ejec_12_eda_temporal.png), [`ejec_13`](evidencias/capturas/ejec_13_eda_pago_zonas.png), [`ejec_14`](evidencias/capturas/ejec_14_eda_tarifas_propinas.png)) y en el tablero (capturas [58](evidencias/capturas/58_tablero_exploratorio.png)–[60](evidencias/capturas/60_tablero_predicciones.png)). Los valores con ≈ se leyeron de los gráficos.

### Temporales
- **H1 — Enero es el mes más bajo y la demanda se recupera en primavera.** Enero 2022 tuvo 2,463,900 viajes (≈ 79.5 mil/día) frente a ≈ 120 mil/día en abril y 118.6 mil/día en octubre, el máximo absoluto con 3,675,372 viajes. Es decir, **+49 %** entre enero y octubre. Coincide con la ola de Ómicron y el invierno de enero 2022.
- **H2 — Bache de verano.** Julio–septiembre baja a ≈ 102–106 mil viajes/día (julio −10.8 % respecto a junio). Se explica por vacaciones y menos desplazamientos laborales y de oficina en Manhattan. La demanda repunta en octubre.
- **H6 — Ciclo semanal y efecto de feriados.** La serie diaria de propinas de octubre–noviembre (gráfico P2) oscila con un patrón semanal claro, entre ≈ 200 y 300 mil USD diarios. En **Thanksgiving (24-nov)** cae a ≈ 146 mil USD, alrededor de la mitad de un día normal: los feriados vacían la ciudad de viajes laborales.

### Categóricas (tipo de pago y tarifa)
- **H3 — La tarjeta domina y la propina en efectivo no existe en los datos.** Tarjeta 75.94 % de los viajes, efectivo 19.59 %, sin dato 3.43 %, disputa 0.57 % y sin cargo 0.48 %. En efectivo, el **99.98 %** de los viajes tiene propina = 0: no es que no se dé propina, sino que **no se registra**. Por eso todo el análisis de propinas y los modelos usan solo pagos con tarjeta. Con tarjeta, solo el 3.97 % deja propina 0 y el promedio es 3.41 USD.
- **H4 — La tarifa estándar es el 91.3 % de los viajes.** Le siguen JFK con tarifa plana (3.76 %), negociada (0.78 %), código desconocido 99 (0.33 %), Newark (0.27 %) y Nassau/Westchester (0.13 %). Los viajes al aeropuerto son pocos en proporción, pero son los de mayor tarifa y propina: el modelo predice ≈ 11.5 USD de propina para JFK → Midtown, frente a ≈ 2–2.6 USD en viajes dentro de Manhattan (gráfico P6).

### Económicas
- **H5 — Los viajes típicos son cortos y baratos, con colas extremas que son errores.** Mediana de tarifa 10 USD, propina 2.16 USD, distancia 1.9 mi y duración 12.2 min. El percentil 99 es 60 USD y 20 mi, pero los máximos (401,092 USD, 389,678 mi, 10 millones de minutos) son errores de captura; por eso se aplicaron los filtros de la sección 1.
- **H7 — El porcentaje de propina es casi independiente del viaje.** El clasificador de propina alta (≥ 20 %) tiene ROC-AUC ≈ 0.56 y asigna probabilidades parecidas (0.69–0.83) a viajes tan distintos como un traslado al aeropuerto en hora pico y un viaje corto al mediodía (sección 9). El porcentaje depende más del pasajero, probablemente de los porcentajes sugeridos en la pantalla del taxi, que de la ruta o la hora.
- **H8 — El monto de la propina sigue a la tarifa.** En los viajes hipotéticos (P6), la propina predicha ronda el 21–24 % de la tarifa para tarifas de 11.5 a 52 USD. Solo el viaje mínimo (5.5 USD) sube al 38 %, porque hay un monto mínimo de propina. Por eso el modelo lineal gana: la relación propina–tarifa es casi proporcional (sección 9.5).

### Geográficas
- **H9 — La demanda se concentra en Manhattan y JFK** (mapa V4 y barras V5, [captura 59](evidencias/capturas/59_tablero_geografico.png)). La zona con más viajes es **Upper East Side South (237)**, con **1,675,569** viajes. Le siguen JFK Airport (132), Upper East Side North (236), Midtown Center (161), Penn Station/Madison Sq West (186), Midtown East (162), Lincoln Square East (142), Murray Hill (170) y Times Sq/Theatre District (230), con ≈ 1.1–1.7 millones cada una. Esas 9 zonas suman ≈ un tercio de todos los viajes (≈ 12 de ≈ 35 millones). Salvo JFK, todas están en Manhattan, y el mapa muestra que el resto de los boroughs casi no genera viajes de taxi amarillo.
- **H10 — Los aeropuertos son pocos viajes, pero valen más.** JFK es la 2.ª zona de origen con más viajes y la de mayor propina en USD: ≈ 11.5 USD predichos hacia Midtown frente a ≈ 2.6 USD dentro de Manhattan. En porcentaje no destaca (≈ 22 %, igual que un viaje urbano): su ventaja viene de la distancia y la tarifa, no de pasajeros más generosos.

## 11. Informe visual
**Enlace al tablero de Looker Studio:** https://datastudio.google.com/reporting/88825b74-66a1-4d74-90cc-d75f74511091

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
| Tablero de Looker Studio | [58 exploración temporal y pagos](evidencias/capturas/58_tablero_exploratorio.png) · [59 zonas y propinas](evidencias/capturas/59_tablero_geografico.png) · [60 modelos y predicciones](evidencias/capturas/60_tablero_predicciones.png) |
| Ejecución de los scripts en BigQuery | [09 hiperparámetros](evidencias/capturas/ejec_09_hiperparametros.png) · [09 código 9.4–9.5](evidencias/capturas/ejec_09_hiperparametros_codigo.png) · [11 rolling forecast](evidencias/capturas/ejec_11_rolling_forecast.png) · [12 EDA temporal](evidencias/capturas/ejec_12_eda_temporal.png) · [13 EDA pago y zonas](evidencias/capturas/ejec_13_eda_pago_zonas.png) · [14 EDA tarifas y propinas](evidencias/capturas/ejec_14_eda_tarifas_propinas.png) · [Looker: fuentes `dash_*`](evidencias/capturas/ejec_looker_fuentes_dash.png) |

Salidas en texto: [`evidencias/salidas/`](evidencias/salidas/).

## 13. Cómo reproducir
1. Crear un proyecto de Google Cloud con facturación activa y autenticar la CLI (`gcloud auth login`, `gcloud config set project <ID>`).
2. Reemplazar `ss22s2026-g8-proyecto2` por el ID del proyecto en `sql/*.sql`.
3. Ejecutar en orden con `./scripts/run_sql.sh sql/<archivo>.sql`: `00 → 03 → 05 → 06 → 08 → 09 → 10 → 11 → 15`. Los scripts `01`, `02`, `04`, `07` y `12`–`14` son de exploración/evidencia y se ejecutan por bloques en la consola de BigQuery (para `04`, con la caché de consultas desactivada).
4. El dataset debe crearse en la región `US`, igual que el dataset público.
5. Costo aproximado: `09` y `11` entrenan 5 modelos adicionales (3 sobre muestras del 25 %). Los modelos ARIMA_PLUS usan una serie de ~330 filas y su costo es despreciable.
6. Crear el tablero siguiendo [`informe_visual/GUIA_TABLERO.md`](informe_visual/GUIA_TABLERO.md) y pegar el enlace en la sección 11.

## 14. Revisión final contra la rúbrica

| Criterio (puntos) | Dónde se cumple | Estado |
|---|---|---|
| Requisito: BigQuery + NYC Taxi 2022 con ≥ 1 M registros | Sección 1 (36,256,539 registros), captura 02 | ✅ |
| Requisito: optimización y clustering obligatorio | Sección 3, `03`, capturas 07–10 | ✅ |
| Requisito: carpeta Proyecto_2 con SQL, evidencias, README e informe visual | Este repositorio | ✅ |
| 1.1 Conexión y comprensión del dataset (8) | Sección 1, `01`, `02` | ✅ |
| 1.2 Consultas SQL avanzadas y transformaciones (8) | `05`, `12`–`15`, capturas `ejec_12`–`ejec_14` | ✅ |
| 1.3 Optimización con particiones y clustering (12) | Sección 3, `03`, `04` | ✅ |
| 1.4 Al menos 2 modelos en BigQuery ML (8) | Sección 8, `06` (3 modelos) + `09` (3 variantes) + `11` (rolling) | ✅ |
| 1.5 Evaluación y comparación con métricas e hiperparámetros (12) | Sección 9, `08`, `09`, captura 60 | ✅ |
| 1.6 Data leakage y split (12) | Sección 7 y 9.2, `05`, `07` | ✅ |
| 2.1 Análisis de patrones y tendencias (10) | Sección 10 (H1–H10) | ✅ |
| 2.2 Visualización exploratoria y de predicciones (10) | Sección 11, capturas 58–60 | ✅ |
| 2.3 Ingeniería de características (10) | Sección 5 | ✅ |
| 2.4 Variables de entrada, salida y objetivo (5) | Sección 6 | ✅ |
| 2.5 Comparación estándar vs. optimizada (5) | Sección 3, capturas 11–17 | ✅ |

**Pendiente:** completar el carné de Estuardo en la tabla de integrantes.
