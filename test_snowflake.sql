-- ================================================
-- Script de Pruebas Snowflake - S3-KMS Integration
-- ================================================

-- 1. CONFIGURACIÓN INICIAL
-- ================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE DEMO_KMS_V3;
USE SCHEMA DEMO_SCHEMA;

-- 2. VERIFICAR STORAGE INTEGRATION
-- ================================================

-- Ver detalles de la integración
DESC INTEGRATION S3_INTEGRATION_KMS;

-- Ver configuración
SHOW INTEGRATIONS LIKE 'S3_INTEGRATION_KMS';

-- Obtener IAM User y External ID (importante para configuración AWS)
DESC INTEGRATION S3_INTEGRATION_KMS;
-- Buscar en los resultados:
-- - STORAGE_AWS_IAM_USER_ARN
-- - STORAGE_AWS_EXTERNAL_ID

-- 3. VERIFICAR STAGE
-- ================================================

-- Ver detalles del stage
DESC STAGE S3_STAGE_KMS;

-- Listar archivos en el stage
LIST @S3_STAGE_KMS;

-- Verificar configuración del stage
SHOW STAGES LIKE 'S3_STAGE_KMS';

-- 4. CREAR TABLA DE PRUEBA
-- ================================================

-- Tabla simple para tests
CREATE OR REPLACE TABLE test_kms_load (
    id INTEGER,
    name VARCHAR(100),
    value DECIMAL(10,2),
    created_date DATE,
    description VARCHAR(500)
);

-- Ver estructura
DESC TABLE test_kms_load;

-- 5. CARGAR DATOS DESDE S3
-- ================================================

-- Listar archivos disponibles
LIST @S3_STAGE_KMS;

-- Cargar datos (ajusta el nombre del archivo según lo que subiste)
COPY INTO test_kms_load
FROM @S3_STAGE_KMS/test_upload.csv
FILE_FORMAT = (
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
)
ON_ERROR = 'CONTINUE';

-- Ver resultados de la carga
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- 6. VERIFICAR DATOS CARGADOS
-- ================================================

-- Contar registros
SELECT COUNT(*) as total_records FROM test_kms_load;

-- Ver primeros registros
SELECT * FROM test_kms_load LIMIT 10;

-- 7. TEST DE ESCRITURA (UNLOAD)
-- ================================================

-- Descargar datos de vuelta a S3
COPY INTO @S3_STAGE_KMS/export/
FROM (
    SELECT * FROM test_kms_load
)
FILE_FORMAT = (
    TYPE = 'CSV'
    COMPRESSION = 'GZIP'
    FIELD_DELIMITER = ','
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
)
HEADER = TRUE
OVERWRITE = TRUE;

-- Verificar archivos exportados
LIST @S3_STAGE_KMS/export/;

-- 8. TEST DE ENCRIPTACIÓN
-- ================================================

-- Crear archivo de prueba con datos sensibles
CREATE OR REPLACE TABLE sensitive_data AS
SELECT
    seq4() as id,
    'User_' || seq4() as username,
    'Email_' || seq4() || '@test.com' as email,
    ROUND(UNIFORM(1000, 9999, RANDOM()), 2) as salary,
    CURRENT_TIMESTAMP() as created_at
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- Ver muestra
SELECT * FROM sensitive_data LIMIT 5;

-- Exportar a S3 (se encriptará con KMS automáticamente)
COPY INTO @S3_STAGE_KMS/sensitive/data_
FROM sensitive_data
FILE_FORMAT = (TYPE = 'PARQUET')
MAX_FILE_SIZE = 52428800;

-- Verificar exportación
LIST @S3_STAGE_KMS/sensitive/;

-- Limpiar tabla
DROP TABLE sensitive_data;

-- 9. VERIFICAR PERMISOS
-- ================================================

-- Ver permisos de la integración
SHOW GRANTS ON INTEGRATION S3_INTEGRATION_KMS;

-- Ver permisos del stage
SHOW GRANTS ON STAGE S3_STAGE_KMS;

-- 10. TROUBLESHOOTING
-- ================================================

-- Si hay errores, verificar:

-- a) Historial de queries
SELECT
    query_id,
    query_text,
    start_time,
    end_time,
    execution_status,
    error_code,
    error_message
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE query_text LIKE '%COPY%'
    AND start_time > DATEADD(hour, -1, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 10;

-- b) Ver errores específicos de COPY
SELECT 
    *
FROM TABLE(VALIDATE(test_kms_load, JOB_ID => '_last'));

-- c) Ver información del sistema
SHOW PARAMETERS LIKE '%AWS%' IN ACCOUNT;

-- 11. CLEANUP (OPCIONAL)
-- ================================================

-- Eliminar archivos del stage
-- REMOVE @S3_STAGE_KMS/test_upload.csv;
-- REMOVE @S3_STAGE_KMS PATTERN='.*.csv';

-- Limpiar tabla de prueba
-- DROP TABLE IF EXISTS test_kms_load;

-- 12. PRUEBAS AVANZADAS
-- ================================================

-- Test de rendimiento: Carga masiva
CREATE OR REPLACE TABLE performance_test AS
SELECT
    seq4() as id,
    RANDSTR(50, RANDOM()) as random_string,
    UNIFORM(1, 1000000, RANDOM()) as random_number,
    CURRENT_TIMESTAMP() as timestamp
FROM TABLE(GENERATOR(ROWCOUNT => 100000));

-- Exportar a S3 con compresión
COPY INTO @S3_STAGE_KMS/performance/data_
FROM performance_test
FILE_FORMAT = (
    TYPE = 'CSV'
    COMPRESSION = 'GZIP'
)
MAX_FILE_SIZE = 104857600
HEADER = TRUE;

-- Ver archivos generados
LIST @S3_STAGE_KMS/performance/;

-- Medir tiempo de carga de vuelta
CREATE OR REPLACE TABLE performance_test_reload (LIKE performance_test);

COPY INTO performance_test_reload
FROM @S3_STAGE_KMS/performance/
FILE_FORMAT = (
    TYPE = 'CSV'
    COMPRESSION = 'GZIP'
    SKIP_HEADER = 1
);

-- Verificar que los datos coinciden
SELECT COUNT(*) FROM performance_test;
SELECT COUNT(*) FROM performance_test_reload;

-- Cleanup performance test
DROP TABLE performance_test;
DROP TABLE performance_test_reload;
REMOVE @S3_STAGE_KMS/performance/ ;

-- 13. VERIFICACIÓN FINAL
-- ================================================

-- Resume del stage
SELECT 
    'Stage configured correctly' as status,
    COUNT(*) as files_in_stage
FROM TABLE(RESULT_SCAN(SYSTEM$LIST_STAGE('@S3_STAGE_KMS')));

-- Verificar database y schema
SELECT CURRENT_DATABASE(), CURRENT_SCHEMA();

-- Listar todos los objetos creados
SHOW TABLES IN SCHEMA DEMO_SCHEMA;
SHOW STAGES IN SCHEMA DEMO_SCHEMA;
SHOW INTEGRATIONS;

-- ================================================
-- FIN DEL SCRIPT
-- ================================================

-- NOTAS:
-- 1. Todos los archivos en S3 están encriptados con KMS automáticamente
-- 2. La encriptación es transparente para Snowflake
-- 3. Verifica en AWS que los objetos usen SSE-KMS
-- 4. El bucket key está habilitado para reducir costos
