-- Test Snowflake S3 Integration with KMS
-- Execute these commands in your Snowflake console

USE ROLE ACCOUNTADMIN;
USE DATABASE DEMO_KMS_V3;
USE SCHEMA DEMO_SCHEMA;

-- 1. Verify Storage Integration
DESC INTEGRATION S3_INTEGRATION_KMS;

-- 2. List files in the S3 stage
LIST @S3_STAGE_KMS;

-- 3. Create a test table
CREATE OR REPLACE TABLE test_kms_load (
  nombre STRING,
  edad INTEGER,
  ciudad STRING
);

-- 4. Load data from S3 (this will test the full integration)
COPY INTO test_kms_load
FROM @S3_STAGE_KMS/test_data.csv
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"');

-- 5. Verify data was loaded
SELECT * FROM test_kms_load;

-- 6. Check the load history
SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
  TABLE_NAME => 'TEST_KMS_LOAD',
  START_TIME => DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
));
