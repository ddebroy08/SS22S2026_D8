# Guía del tablero — Looker Studio

Tablero del Proyecto 2 (SS22S2026, Grupo 8). Todas las fuentes son tablas **agregadas** del dataset `ss22s2026-g8-proyecto2.nyc_taxi_p2`, creadas por `sql/15_tablas_dashboard.sql` (exploratorias) y `sql/08`–`11` (predicciones). Así cada gráfico lee pocos KB y no escanea los ~7 GB de la tabla original cada vez que alguien mueve un filtro.

## Cómo crearlo
1. Ejecutar `sql/08` → `sql/11` y `sql/15` en BigQuery.
2. En [lookerstudio.google.com](https://lookerstudio.google.com) ir a **Crear → Informe → Agregar datos → BigQuery**, elegir el proyecto `ss22s2026-g8-proyecto2` y el dataset `nyc_taxi_p2`, y agregar las tablas de la lista de abajo como fuentes de datos.
3. Armar las 3 páginas descritas abajo.
4. Ir a **Compartir → Cualquier persona con el enlace puede ver**, copiar el enlace y pegarlo en el `README.md` (sección 11).
5. Guardar una captura de cada página en `evidencias/capturas/` (`58_tablero_exploratorio.png`, `59_tablero_geografico.png`, `60_tablero_predicciones.png`).

## Página 1 — Exploración temporal y de pago

| # | Gráfico | Fuente | Dimensión | Métrica(s) | Qué muestra |
|---|---|---|---|---|---|
| V1 | Serie de tiempo | `dash_diario` | `fecha` | `viajes` (eje izq.), `propina_prom_tarjeta` (eje der.) | Tendencia anual, caída de enero y de verano, ciclo semanal |
| V2 | Tabla dinámica con mapa de calor | `dash_hora_dia` | filas `hora`, columnas `dia_semana` | `viajes_por_dia` | Horas pico entre semana vs. madrugada de fin de semana |
| V3 | Barras apiladas 100 % | `dash_pago_mensual` | `mes`, desglose `tipo_pago` | `viajes` | Participación tarjeta vs. efectivo por mes |
| — | Control de período | `dash_diario` | `fecha` | — | Filtra V1 |

## Página 2 — Zonas, tarifas y propinas

| # | Gráfico | Fuente | Dimensión | Métrica(s) | Qué muestra |
|---|---|---|---|---|---|
| V4 | Mapa de Google (área rellena) | `dash_zonas` | `zone_geom` (geometría), `zona` | color: `viajes` (o `propina_pct_tarjeta`) | Concentración de demanda en Manhattan y aeropuertos |
| V5 | Barras | `dash_zonas` | `zona` (top 15 por `viajes`) | `viajes`, `propina_prom_tarjeta` | Zonas con más viajes |
| V6 | Combinado (barras + línea) | `dash_distancia_propina` | `rango_distancia`, filtro `is_airport` | `propina_prom` (barras), `propina_pct_prom` (línea) | La propina en USD sube con la distancia mientras el % baja |
| — | Control desplegable | `dash_zonas` | `borough` | — | Filtra V4 y V5 |

## Página 3 — Modelos y predicciones (BigQuery ML)

| # | Gráfico | Fuente | Dimensión | Métrica(s) | Qué muestra |
|---|---|---|---|---|---|
| P1 | Serie de tiempo | `pred_diaria_nov` | `fecha` | `propina_total_real`, `propina_total_pred_linear`, `propina_total_pred_boosted` | Predicción vs. realidad en noviembre (registros nuevos) |
| P2 | Serie de tiempo (filtro `ventana`) | `rolling_forecast_diario` | `fecha` | `propina_real`, `pred_boosted`, `pred_arima`, `arima_limite_inf_90`, `arima_limite_sup_90` | **Rolling Forecast:** las 2 predicciones (W1 → oct, W2 → nov) |
| P3 | Tabla con barras | `rolling_forecast_resumen` | `ventana` | `mape_boosted_pct`, `mape_arima_pct`, `pct_dias_dentro_ic90_arima` | Error de cada método por ventana |
| P4 | Barras | `eval_hiperparametros` | `modelo` | `rmse` (regresión) / `roc_auc` (clasificación) | Comparación de modelos e hiperparámetros |
| P5 | Dispersión | `eval_roc_logistic` | `threshold` | x = `false_positive_rate`, y = `recall` | Curva ROC del modelo logístico |
| P6 | Tabla | `pred_viajes_hipoteticos` | `escenario` | `pred_tip_linear`, `pred_tip_boosted`, `prob_high_tip` | Predicciones sobre viajes nuevos escritos a mano |
