-- Ejercicio 1: Arquitectura de Datos (Física)

CREATE SCHEMA `sprint3_silver`
OPTIONS(
  location = 'EU'
);

-- Ejercicio 2: Ingesta en Capa Bronze (Conexión DDL)
CREATE OR REPLACE EXTERNAL TABLE `sprint3_bronze.transactions_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'],
  field_delimiter = ';',
  skip_leading_rows = 1
);

CREATE OR REPLACE EXTERNAL TABLE `sprint3_bronze.companies_raw` (
  id STRING,
  company_name STRING,
  address STRING,
  city STRING,
  country STRING,
  phone STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'],
  skip_leading_rows = 1
);

CREATE OR REPLACE EXTERNAL TABLE `sprint3_bronze.american_users_raw` (
  id STRING,
  first_name STRING,
  last_name STRING,
  email STRING,
  phone STRING,
  address STRING,
  city STRING,
  state STRING,
  zip STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv'],
  skip_leading_rows = 1
);

CREATE OR REPLACE EXTERNAL TABLE `sprint3_bronze.european_users_raw` (
  id STRING,
  first_name STRING,
  last_name STRING,
  email STRING,
  phone STRING,
  address STRING,
  city STRING,
  country STRING,
  postal_code STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv'],
  skip_leading_rows = 1
);


CREATE OR REPLACE EXTERNAL TABLE `sprint3_bronze.credit_cards_raw` (
  id STRING,
  user_id STRING,
  card_number STRING,
  card_type STRING,
  expiration_date STRING,
  cvv STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv'],
  skip_leading_rows = 1
);

-- Ejercicio 4: Arquitectura y Rendimiento. Materialización de Datos (Asistido por IA)
-- a) Materialización de Datos (Asistido por IA)
CREATE OR REPLACE TABLE
  `sprint3-analytics-leoruggiero`.`sprint3_bronze`.`transactions_raw_native` AS
SELECT
  id,
  card_id,
  business_id,
  timestamp,
  amount,
  declined,
  product_ids,
  user_id,
  lat,
  longitude
FROM
  `sprint3-analytics-leoruggiero`.`sprint3_bronze`.`transactions_raw`;

-- b) Auditoría de Costes
SELECT id FROM `sprint3_bronze.transactions_raw`;

SELECT id FROM `sprint3_bronze.transactions_raw_native`;

-- c) El peligro del LIMIT

SELECT * FROM `sprint3_bronze.transactions_raw` LIMIT 10;


-- Ejercicio 5: Adaptación de Sintaxis (Reporting)
SELECT column_name, data_type AS validacion_tecnica
FROM `sprint3-analytics-leoruggiero.sprint3_bronze.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'transactions_raw_native' AND column_name = 'timestamp';

SELECT DATE(timestamp) AS fecha, SUM(amount) AS ingresos_totales
FROM `sprint3-analytics-leoruggiero.sprint3_bronze.transactions_raw_native`
WHERE EXTRACT(YEAR FROM timestamp) = 2021 AND declined = 0
GROUP BY fecha
ORDER BY ingresos_totales DESC
LIMIT 5;


-- Ejercicio 6: Consultas Complejas

SELECT
  c.company_name AS nombre_empresa,
  c.country AS pais,
  t.timestamp AS fecha_transaccion
FROM `sprint3-analytics-leoruggiero.sprint3_bronze.transactions_raw_native` AS t
INNER JOIN `sprint3-analytics-leoruggiero.sprint3_bronze.companies_raw` AS c
  ON t.business_id = c.id
WHERE
  t.amount BETWEEN 100 AND 200
  AND DATE(t.timestamp) IN ('2015-04-29', '2018-07-20', '2024-03-13');


-- Nivel 2: Limpieza y Transformación (ELT)
-- Ejercicio 1: Limpieza de Productos (Data Quality)

CREATE TABLE `sprint3-analytics-leoruggiero.sprint3_silver.products_clean`
AS
SELECT
    id AS product_id,
    
    product_name AS name,
    
    CAST(REPLACE(warehouse_id, 'WH-', '') AS INT64) AS warehouse_id,
    
    CAST(price AS FLOAT64) AS price,
    
    weight
FROM 
    `sprint3-analytics-leoruggiero.sprint3_bronze.products_raw`;




-- Ejercicio 2: Creación de Transacciones Limpias (Capa Silver)

CREATE OR REPLACE TABLE `sprint3-analytics-leoruggiero.sprint3_silver.transactions_clean`
AS
SELECT
    id AS transaction_id,
    card_id,
    business_id,
    
    CAST(timestamp AS TIMESTAMP) AS timestamp,
    
    IFNULL(SAFE_CAST(amount AS FLOAT64), 0) AS amount,
    
    declined,

    ARRAY(
      SELECT CAST(TRIM(p_id) AS INT64) 
      FROM UNNEST(SPLIT(product_ids, ',')) AS p_id
      WHERE TRIM(p_id) != ""
    ) AS product_ids,
    
    user_id,
    
    SAFE_CAST(lat AS FLOAT64) AS lat,
    SAFE_CAST(longitude AS FLOAT64) AS longitude
FROM 
    `sprint3-analytics-leoruggiero.sprint3_bronze.transactions_raw_native`;



-- Ejercicio 3: Unificación de Usuarios (UNION)


CREATE OR REPLACE TABLE `sprint3-analytics-leoruggiero.sprint3_silver.users_combined` AS
SELECT 
    id AS user_id, 
    name, 
    surname, 
    phone, 
    email, 
    birth_date, 
    country, 
    city, 
    postal_code, 
    address,
    'USA' AS origin
FROM 
    `sprint3-analytics-leoruggiero.sprint3_bronze.american_users_raw`

UNION ALL

SELECT 
    id AS user_id, 
    name, 
    surname, 
    phone, 
    email, 
    birth_date, 
    country, 
    city, 
    postal_code, 
    address,
    'EUROPE' AS origin
FROM 
    `sprint3-analytics-leoruggiero.sprint3_bronze.european_users_raw`;


-- Ejercicio 4: Materialización de Compañías y Tarjetas de Crédito

CREATE OR REPLACE TABLE `sprint3-analytics-leoruggiero.sprint3_silver.companies_clean` AS
SELECT 
    company_id,
    company_name, 
    phone, 
    email, 
    country, 
    website
FROM 
    `sprint3-analytics-leoruggiero.sprint3_bronze.companies_raw`;

CREATE OR REPLACE TABLE `sprint3-analytics-leoruggiero.sprint3_silver.credit_cards_clean` AS
SELECT 
    id AS card_id,
    user_id, 
    iban, 
    pan, 
    pin, 
    cvv, 
    track1, 
    track2, 
    expiring_date
FROM 
    `sprint3-analytics-leoruggiero.sprint3_bronze.credit_cards_raw`;


-- Nivel 3: Presentación de Datos y Creación de Vistas

-- Ejercicio 1: La Vista de Marketing (Lógica de Negocio)
CREATE OR REPLACE VIEW `sprint3-analytics-leoruggiero.sprint3_gold.v_marketing_kpis`
AS
SELECT 
    c.company_name,
    c.phone,
    c.country,
    ROUND(AVG(t.amount), 2) AS avg_amount,
    CASE 
        WHEN AVG(t.amount) > 260 THEN 'Premium'
        ELSE 'Standard'
    END AS client_tier
FROM `sprint3-analytics-leoruggiero.sprint3_silver.companies_clean` AS c
JOIN `sprint3-analytics-leoruggiero.sprint3_silver.transactions_clean` AS t
    ON c.company_id = t.business_id
WHERE t.declined = 0
GROUP BY c.company_name, c.phone, c.country;


SELECT * FROM `sprint3_gold.v_marketing_kpis`
ORDER BY 
client_tier ASC,
avg_amount DESC


-- Ejercicio 2: Ranking de Productos (La Potencia de los Arrays)
CREATE OR REPLACE TABLE `sprint3-analytics-leoruggiero.sprint3_gold.product_sales_ranking` AS
SELECT 
    p.product_id,
    p.name,
    p.price,
    IFNULL(COUNT(t.unfolded_product_id), 0) AS total_sold
FROM 
    `sprint3-analytics-leoruggiero.sprint3_silver.products_clean` AS p
LEFT JOIN (
    SELECT 
        p_id AS unfolded_product_id
    FROM 
        `sprint3-analytics-leoruggiero.sprint3_silver.transactions_clean`,
        UNNEST(product_ids) AS p_id
    WHERE 
        SAFE_CAST(declined AS STRING) = '0' 
) AS t
    ON SAFE_CAST(p.product_id AS STRING) = SAFE_CAST(t.unfolded_product_id AS STRING)
GROUP BY 
    p.product_id,
    p.name,
    p.price;




    SELECT * FROM `sprint3-analytics-leoruggiero.sprint3_gold.product_sales_ranking`
ORDER BY total_sold DESC;


-- Ejercicio 3: Exportación de Resultados

SELECT * FROM `sprint3-analytics-leoruggiero.sprint3_gold.product_sales_ranking`
ORDER BY total_sold DESC; 