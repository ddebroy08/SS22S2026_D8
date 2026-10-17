# Proyecto 2: Procesamiento y Análisis Exploratorio de Datos Masivos en BigQuery

**Universidad de San Carlos de Guatemala**  
**Facultad de Ingeniería**  
**Escuela de Ciencias y Sistemas**  
**Seminario de Sistemas 2**  

* **Ponderación:** 25 pts (escala de 100 pts en rúbrica)
* **Tiempo estimado:** 22 hrs
* **Modalidad:** Parejas (en el repositorio grupal `SS22S2026_#GRUPO`)

---

## Índice
1. [Marco Formativo](#1-marco-formativo)
   - [1.1. Valor](#11-valor)
   - [1.2. Competencia(s)](#12-competencias)
   - [1.3. Objetivo SMART](#13-objetivo-smart)
2. [Resumen Ejecutivo](#2-resumen-ejecutivo)
3. [Enunciado del Proyecto](#3-enunciado-del-proyecto)
   - [3.1 Descripción del problema a resolver](#31-descripción-del-problema-a-resolver)
   - [3.2 Alcance del proyecto (Obligatorio)](#32-alcance-del-proyecto)
   - [3.3 Requerimientos técnicos](#33-requerimientos-técnicos)
   - [3.4 Entregables](#34-entregables)
4. [Material de Apoyo](#4-material-de-apoyo)
5. [Metodología](#5-metodología)
6. [Recursos y Herramientas a Utilizar](#6-recursos-y-herramientas-a-utilizar)
7. [Desarrollo de Habilidades Blandas](#7-desarrollo-de-habilidades-blandas)
8. [Cronograma](#8-cronograma)
9. [Rúbrica de Calificación](#9-rúbrica-de-calificación)
   - [9.1 Requisitos para optar a la calificación](#91-requisitos-para-optar-a-la-calificación)
   - [9.2 Resumen de Puntuaciones](#92-resumen-de-puntuaciones)
   - [9.3 Detalle de la Calificación](#93-detalle-de-la-calificación)

---

## 1. Marco Formativo

### 1.1. Valor
| Nombre del valor | ¿Cómo se aplica en tu laboratorio? |
| :--- | :--- |
| **Rigor analítico y responsabilidad profesional** | Uso correcto del dataset público, ejecución eficiente de consultas SQL, optimización responsable de recursos en la nube y documentación transparente de hallazgos. |

### 1.2. Competencia(s)
| Tipo de Competencia | Descripción |
| :--- | :--- |
| **Competencia General** | Maneja e interpreta adecuadamente datos masivos, sean estos estructurados o no estructurados, facilitando su visualización e interpretación de forma eficaz en apoyo a la toma de decisiones. |
| **Competencia Específica** | Administra proyectos de análisis de datos en la nube con herramientas como BigQuery y Google Cloud Platform aplicando principios de gobierno de datos, seguridad y control de acceso. |

### 1.3. Objetivo SMART
| Dimensión SMART | Definición | Objetivo redactado |
| :--- | :--- | :--- |
| **Específico (¿Qué?)** | El objetivo es concreto y tangible. | Diseñar e implementar un proceso de análisis exploratorio sobre el dataset público NYC Taxi Trips 2022 en BigQuery, aplicando consultas SQL, tablas derivadas, particiones y clustering para identificar patrones relevantes. |
| **Medible (¿Cuánto?)** | El objetivo tiene una medida objetiva de éxito. | Se considerará cumplido al entregar consultas SQL funcionales, evidencia de optimización en bytes procesados, un informe visual con 3 visualizaciones y un README técnico con hallazgos documentados. |
| **Alcanzable (¿Cómo?)** | El objetivo debe ser posible con los recursos disponibles. | El objetivo puede lograrse con una cuenta activa de Google Cloud Platform, BigQuery, Google Sheets o Looker Studio y un repositorio organizado en GitHub. |
| **Realista (¿Para qué?)** | El objetivo contribuye a metas más amplias. | Fortalece las competencias en análisis de datos masivos, optimización de consultas, documentación técnica y comunicación de hallazgos en entornos de analítica en la nube. |
| **A Tiempo (¿Cuándo?)** | El objetivo tiene fecha límite o cronograma de hitos. | Debe entregarse según el cronograma oficial del proyecto: asignación el 08 de abril, entrega el 29 de abril. |

---

## 2. Resumen Ejecutivo

En esta fase, los estudiantes trabajarán con el dataset público **New York City Taxi Trips 2022**, disponible en **Google BigQuery**, que contiene más de 100 millones de registros de viajes de taxi en la ciudad de Nueva York.

El proyecto busca desarrollar competencias en análisis exploratorio de datos masivos utilizando SQL en BigQuery, aplicando técnicas de transformación y optimización de consultas mediante particiones y clustering, y comunicando hallazgos relevantes mediante visualizaciones iniciales.

Utilizando **BigQuery ML**, se entrenarán al menos 2 modelos distintos de regresión o clasificación, se evaluará su desempeño mediante métricas como precisión, error cuadrático medio o matriz de confusión, y se aplicará sobre nuevos datos. Finalmente, se construirá un tablero en **Google Data Studio (Looker Studio)** para comunicar visualmente los resultados y sus implicaciones.

---

## 3. Enunciado del Proyecto

### 3.1 Descripción del problema a resolver
El análisis de grandes volúmenes de datos representa un reto cuando las consultas son lentas, costosas o difíciles de interpretar. En este proyecto se utilizará el dataset público NYC Taxi Trips 2022 en BigQuery, con más de 100 millones de registros, para transformar datos masivos en información útil.

El estudiante deberá:
1. Diseñar consultas SQL.
2. Aplicar técnicas de optimización mediante particiones y clustering.
3. Identificar patrones significativos de viaje, costo y comportamiento de usuarios.
4. Presentar hallazgos mediante visualizaciones exploratorias claras.

### 3.2 Alcance del proyecto
**Obligatorio:**
* **Conectarse al dataset público:**
  `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
* **Consultas SQL avanzadas:** Calcular métricas descriptivas, analizar distribuciones categóricas y detectar patrones temporales.
* **Crear tablas derivadas:** Trabajar subconjuntos optimizados del dataset en su propio proyecto de GCP.
* **Implementar particiones y clustering:**
  - Particiones por fecha.
  - Clustering por ubicaciones para reducir el costo de procesamiento.
* **Comparación de rendimiento:** Comparar el rendimiento de las consultas antes y después de aplicar optimización (bytes procesados / tiempo de ejecución).
* **Informe visual:** Exportar o enlazar resultados a Google Sheets o Looker Studio para generar al menos **3 visualizaciones exploratorias**.
* **Documentación en repositorio:** Repositorio organizado con scripts SQL, capturas de consultas, evidencias e informe visual.
* **Modelos predictivos en BigQuery ML:**
  - Entrenar al menos **2 modelos predictivos distintos** (regresión o clasificación) sobre un dataset limpio.
  - Implementación y comparación entre modelos con distintas métricas de evaluación e hiperparámetros (ej. ROC-AUC, RMSE, matriz de confusión o iteraciones).
  - Manejo de prevención de *data leakage* mediante `data_split_eval_fraction` y split personalizado.
  - Ejecutar predicciones sobre nuevos registros.
* **Dashboard con resultados de ML:** Representar resultados y hallazgos de los modelos mediante visualizaciones en el dashboard (ej. Rolling Forecast).

### 3.3 Requerimientos técnicos
* **Herramientas:** Google Cloud Platform (GCP), Google BigQuery, Google Sheets o Looker Studio y GitHub.
* **Dataset:** `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
* **Consultas:** Uso de funciones agregadas, funciones temporales, filtros, agrupaciones y transformaciones SQL.
* **Optimización:** Implementación de particiones (definido por el estudiante) y clustering (definido por el estudiante).
* **Conocimientos aplicados:** Análisis exploratorio de datos masivos, optimización de consultas y comunicación visual de hallazgos.

### 3.4 Entregables

| Tipo | Descripción |
| :--- | :--- |
| **Scripts SQL** | Archivo(s) `.sql` con las consultas realizadas en BigQuery para exploración, transformaciones y optimización. Deben estar comentados para explicar la finalidad de cada bloque. |
| **Scripts BigQuery ML** | Script SQL del modelo entrenado y evaluado, y tablas de resultados con predicciones. |
| **Evidencias** | Capturas de pantalla de consultas relevantes en BigQuery, conteo de registros, aplicación de particiones/clustering y evidencia de reducción de bytes procesados. |
| **Informe visual** | Enlace a un tablero de Looker Studio o archivo de Google Sheets enlazado a BigQuery, con al menos **3 visualizaciones exploratorias** de hallazgos clave y la **comparación de al menos 2 predicciones** con los modelos de ML (Rolling Forecast). |
| **Archivo README** | Documento técnico con: nombre del proyecto, dataset utilizado, transformaciones realizadas, técnicas de optimización aplicadas, comparación de desempeño (optimizado vs estándar), hallazgos relevantes, explicación de los modelos de regresión o clasificación en BigQuery ML, y enlace al informe visual. |
| **Repositorio del curso** | Carpeta `Proyecto_2` dentro del repositorio `SS22S2026_#GRUPO`, que contenga todos los archivos del proyecto, documentación y scripts organizados conforme a los lineamientos del laboratorio. En el README deben indicarse ambos integrantes de la pareja. |

---

## 4. Material de Apoyo
* [Documentación oficial de BigQuery](https://cloud.google.com/bigquery/docs)
* [Documentación de BigQuery Public Datasets](https://cloud.google.com/bigquery/public-data)
* [Guías de particiones y clustering](https://cloud.google.com/bigquery/docs/partitioned-tables)

---

## 5. Metodología
1. **Conexión y exploración inicial del dataset:** Acceder al dataset público en BigQuery, validar registros y comprender la estructura de las tablas y variables disponibles.
2. **Desarrollo de consultas SQL y transformaciones:** Construir consultas para filtrar, agrupar, calcular métricas y preparar datos útiles para el análisis exploratorio.
3. **Optimización del procesamiento:** Crear tablas derivadas, aplicar particiones y clustering, y comparar costos de procesamiento antes y después de la optimización.
4. **Visualización y análisis de hallazgos:** Generar visualizaciones exploratorias en Google Sheets o Looker Studio para resumir patrones clave del dataset.
5. **Documentación final:** Elaborar un repositorio organizado con scripts SQL, evidencias, README técnico y conclusiones relevantes del análisis.

---

## 6. Recursos y Herramientas a Utilizar

* **Software:**
  - Google Cloud Platform y Google BigQuery
  - Google Sheets o Looker Studio
* **Plataformas:**
  - GitHub (para repositorio del proyecto)
  - Google Cloud Console (para ejecución y monitoreo de consultas)
* **Lecturas recomendadas:**
  - Documentación oficial de BigQuery y datasets públicos.
  - Guías de particiones, clustering y optimización de consultas.
  - Material de apoyo para visualización de resultados en Google Sheets o Looker Studio.

---

## 7. Desarrollo de Habilidades Blandas

En este proyecto se promueven competencias transversales orientadas al análisis responsable, eficiente y comunicable de datos masivos:
* **Pensamiento analítico:** Interpretación crítica de patrones, tendencias y métricas obtenidas a partir de consultas SQL sobre grandes volúmenes de datos.
* **Responsabilidad en el uso de recursos cloud:** Optimización consciente de consultas para reducir costos de procesamiento y uso eficiente de la plataforma.
* **Comunicación técnica:** Documentación clara de procedimientos, hallazgos y decisiones de diseño para facilitar la trazabilidad del trabajo.

---

## 8. Cronograma

| Tipo | Fecha Inicio | Fecha Fin |
| :--- | :--- | :--- |
| **Asignación de Proyecto** | Semana 12 | Semana 12 |
| **Elaboración** | Semana 12 | Semana 14 |
| **Calificación** | Semana 14 | Semana 14 |

*(Fechas oficiales según cronograma: Asignación el 08 de abril, Entrega el 29 de abril).*

---

## 9. Rúbrica de Calificación

### 9.1 Requisitos para optar a la calificación
> *Todos los requisitos son de cumplimiento obligatorio (Sí/No) para tener derecho a calificación.*

| Tema | Descripción | Cumple (Sí/No) |
| :--- | :--- | :---: |
| **Cumplimiento del dataset y plataforma** | El proyecto debe desarrollarse en Google BigQuery utilizando el dataset público NYC Taxi Trips 2022, con al menos 1 millón de registros. | [ ] |
| **Uso de técnicas requeridas** | Aplicación y evidencia de optimización y clustering obligatorio. | [ ] |
| **Gestión y entregas del proyecto** | El repositorio del curso debe incluir la carpeta `Proyecto_2` con scripts SQL, evidencias, README e informe visual organizados correctamente. | [ ] |
| **Documentación obligatoria** | Debe contener descripción del dataset, transformaciones, optimización aplicada, hallazgos relevantes y enlace al informe visual. | [ ] |
| **Evidencias y funcionalidad mínima** | Análisis exploratorio y documentación. | [ ] |

---

### 9.2 Resumen de Puntuaciones

| Área | Criterio | Puntos Totales |
| :--- | :--- | :---: |
| **1. Habilidades** | Conexión y comprensión del dataset público | 8 |
| | Consultas SQL avanzadas y transformaciones | 8 |
| | Optimización con particiones y clustering | 12 |
| | Implementación correcta de al menos 2 modelos en BigQuery ML | 8 |
| | Evaluación y comparación entre modelos con métricas e hiperparámetros | 12 |
| | Prevención de data leakage y manejo correcto del split de datos | 12 |
| **Subtotal Habilidades** | | **60** |
| **2. Conocimientos** | Análisis correcto de patrones y tendencias | 10 |
| | Visualización de resultados exploratorios y predicciones | 10 |
| | Ingeniería de características y justificación de variables | 10 |
| | Identificación correcta de variables de entrada, salida y objetivo del modelo | 5 |
| | Comparación entre consultas estándar y optimizadas | 5 |
| **Subtotal Conocimientos** | | **40** |
| **TOTAL GENERAL** | | **100** |

---

### 9.3 Detalle de la Calificación

#### 1. Habilidades (60 Puntos)

| No. | Criterio de evaluación | Punteo máx. | Satisfactorio (100% – 61%) | Necesita mejorar (60% – 0%) |
| :---: | :--- | :---: | :--- | :--- |
| **1.1** | **Conexión y comprensión del dataset público** | **8** | Utiliza correctamente el dataset público, valida el volumen de registros y demuestra comprensión de la estructura y calidad de los datos.<br>*(Rango: 8 - 5 pts)* | Presenta errores en el uso del dataset, validación insuficiente o desconocimiento de la estructura de los datos.<br>*(Rango: 4 - 0 pts)* |
| **1.2** | **Consultas SQL avanzadas y transformaciones** | **8** | Aplica consultas SQL funcionales con filtros, funciones agregadas, cálculos y transformaciones coherentes para preparar y explorar los datos.<br>*(Rango: 8 - 5 pts)* | Las consultas presentan errores, resultados inconsistentes o transformaciones insuficientes para sustentar el análisis.<br>*(Rango: 4 - 0 pts)* |
| **1.3** | **Optimización con particiones y clustering** | **12** | Implementa tablas derivadas con particiones y clustering y demuestra con evidencia una mejora en costo o rendimiento de las consultas.<br>*(Rango: 12 - 8 pts)* | No aplica correctamente la optimización, la evidencia es insuficiente o no demuestra mejora respecto a una consulta estándar.<br>*(Rango: 7 - 0 pts)* |
| **1.4** | **Implementación correcta de al menos 2 modelos en BigQuery ML** | **8** | Entrena correctamente al menos 2 modelos en BigQuery ML, con sintaxis válida, datos preparados y resultados reproducibles.<br>*(Rango: 8 - 5 pts)* | Los modelos no entrenan correctamente, presentan errores de implementación o no se evidencia el uso adecuado de BigQuery ML.<br>*(Rango: 4 - 0 pts)* |
| **1.5** | **Evaluación y comparación entre modelos con métricas e hiperparámetros** | **12** | Compara modelos usando métricas pertinentes e hiperparámetros claramente definidos, interpreta los resultados y justifica la selección final.<br>*(Rango: 12 - 8 pts)* | La comparación es superficial o incorrecta, faltan métricas relevantes, no hay ajuste de hiperparámetros o no se justifica la elección del modelo.<br>*(Rango: 7 - 0 pts)* |
| **1.6** | **Prevención de data leakage y manejo correcto del split de datos** | **12** | Aplica correctamente estrategias para evitar data leakage, define adecuadamente training y evaluation set y justifica el método de partición utilizado.<br>*(Rango: 12 - 8 pts)* | Existe fuga de información, el split de datos es incorrecto o no se justifica la estrategia de separación entre entrenamiento y evaluación.<br>*(Rango: 7 - 0 pts)* |

#### 2. Conocimientos (40 Puntos)

| No. | Criterio de evaluación | Punteo máx. | Satisfactorio (100% – 61%) | Necesita mejorar (60% – 0%) |
| :---: | :--- | :---: | :--- | :--- |
| **2.1** | **Análisis correcto de patrones y tendencias** | **10** | Identifica y explica hallazgos relevantes en variables temporales, categóricas, geográficas o económicas, sustentados por el análisis realizado.<br>*(Rango: 10 - 6 pts)* | Los hallazgos son superficiales, poco claros o no están sustentados por el análisis realizado.<br>*(Rango: 5 - 0 pts)* |
| **2.2** | **Visualización de resultados exploratorios y predicciones** | **10** | Presenta visualizaciones claras, funcionales y bien interpretadas, que comunican tanto hallazgos exploratorios como resultados de predicción.<br>*(Rango: 10 - 6 pts)* | Las visualizaciones son confusas, incompletas o no aportan valor para interpretar los hallazgos ni los resultados de los modelos.<br>*(Rango: 5 - 0 pts)* |
| **2.3** | **Ingeniería de características y justificación de variables** | **10** | Construye variables derivadas relevantes y justifica su uso dentro del problema analítico o predictivo planteado.<br>*(Rango: 10 - 6 pts)* | Las variables derivadas son escasas, irrelevantes o no existe justificación clara de por qué fueron utilizadas.<br>*(Rango: 5 - 0 pts)* |
| **2.4** | **Identificación correcta de variables de entrada, salida y objetivo del modelo** | **5** | Define correctamente las variables de entrada, la variable objetivo y el propósito analítico o predictivo de cada modelo.<br>*(Rango: 5 - 3 pts)* | Existe confusión entre variables de entrada y salida, o no se define con claridad el propósito de los modelos.<br>*(Rango: 2 - 0 pts)* |
| **2.5** | **Comparación entre consultas estándar y optimizadas** | **5** | Presenta una comparación clara entre consultas estándar y optimizadas, con evidencia de reducción de bytes procesados o mejora en tiempo de ejecución.<br>*(Rango: 5 - 3 pts)* | La comparación es inexistente, incompleta o no demuestra de forma clara el beneficio de la optimización aplicada.<br>*(Rango: 2 - 0 pts)* |
