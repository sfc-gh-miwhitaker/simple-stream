/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Deploy Pipeline from Git Repository
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Execute SQL scripts from the cloned Git repository to deploy the full pipeline.
 *   Demonstrates Git-based deployment automation pattern.
 * 
 * ARCHITECTURE:
 *   SNOWFLAKE_EXAMPLE (database)
 *   ├── RAW_INGESTION (schema)              - Raw ingestion layer
 *   │   ├── RAW_BADGE_EVENTS (table)        - Snowpipe Streaming target
 *   │   ├── sfe_badge_events_pipe (pipe)    - REST API endpoint
 *   │   └── sfe_badge_events_stream (stream) - CDC stream
 *   ├── STAGING_LAYER (schema)              - Staging/transformation layer
 *   │   ├── STG_BADGE_EVENTS (table)
 *   │   ├── STG_DIM_USERS (table)
 *   │   ├── STG_DIM_ZONES (table)
 *   │   └── STG_DIM_READERS (table)
 *   └── ANALYTICS_LAYER (schema)            - Analytics layer
 *       ├── DIM_USERS (table)
 *       ├── DIM_ZONES (table)
 *       ├── DIM_READERS (table)
 *       └── FCT_ACCESS_EVENTS (table)
 * 
 * PREREQUISITES:
 *   - sql/00_git_setup/01_git_repository_setup.sql executed
 *   - sql/00_git_setup/02_configure_secrets.sql executed
 *   - Uses serverless tasks (no warehouse needed)
 * 
 * USAGE:
 *   Execute this entire file in Snowsight Workspaces (Projects → Workspaces → + SQL File)
 * 
 * CLEANUP:
 *   See sql/99_cleanup/teardown_all.sql for complete removal
 * 
 * ESTIMATED TIME: 2-3 minutes
 ******************************************************************************/

-- Set context
USE ROLE SYSADMIN;
-- No warehouse needed - tasks use serverless compute
USE DATABASE SNOWFLAKE_EXAMPLE;

/*******************************************************************************
 * STEP 1: Create Database and Schemas
 ******************************************************************************/

-- Run sql/01_setup/01_database_and_schemas.sql from Git repository
EXECUTE IMMEDIATE $$
DECLARE
  script STRING;
BEGIN
  -- Read script from Git repository
  SELECT file_content
  INTO :script
  FROM TABLE(
    READ_GIT_FILE(
      repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
      file_path => 'sql/01_setup/01_database_and_schemas.sql',
      ref => 'main'
    )
  );
  
  -- Execute the script
  EXECUTE IMMEDIATE :script;
  
  RETURN 'Step 1 Complete: Database and schemas created';
END;
$$;

/*******************************************************************************
 * STEP 2: Create Raw Table (Snowpipe Streaming Target)
 ******************************************************************************/

EXECUTE IMMEDIATE $$
DECLARE
  script STRING;
BEGIN
  SELECT file_content
  INTO :script
  FROM TABLE(
    READ_GIT_FILE(
      repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
      file_path => 'sql/01_setup/02_raw_table.sql',
      ref => 'main'
    )
  );
  
  EXECUTE IMMEDIATE :script;
  RETURN 'Step 2 Complete: RAW_BADGE_EVENTS table created';
END;
$$;

/*******************************************************************************
 * STEP 3: Create Snowpipe Streaming Pipe (REST API Endpoint)
 ******************************************************************************/

EXECUTE IMMEDIATE $$
DECLARE
  script STRING;
BEGIN
  SELECT file_content
  INTO :script
  FROM TABLE(
    READ_GIT_FILE(
      repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
      file_path => 'sql/01_setup/03_pipe_object.sql',
      ref => 'main'
    )
  );
  
  EXECUTE IMMEDIATE :script;
  RETURN 'Step 3 Complete: sfe_badge_events_pipe created';
END;
$$;

/*******************************************************************************
 * STEP 4: Create Staging Table
 ******************************************************************************/

EXECUTE IMMEDIATE $$
DECLARE
  script STRING;
BEGIN
  SELECT file_content
  INTO :script
  FROM TABLE(
    READ_GIT_FILE(
      repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
      file_path => 'sql/01_setup/04_staging_table.sql',
      ref => 'main'
    )
  );
  
  EXECUTE IMMEDIATE :script;
  RETURN 'Step 4 Complete: STG_BADGE_EVENTS table created';
END;
$$;

/*******************************************************************************
 * STEP 5: Create Dimension Tables
 ******************************************************************************/

EXECUTE IMMEDIATE $$
DECLARE
  script STRING;
BEGIN
  SELECT file_content
  INTO :script
  FROM TABLE(
    READ_GIT_FILE(
      repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
      file_path => 'sql/01_setup/05_dimension_tables.sql',
      ref => 'main'
    )
  );
  
  EXECUTE IMMEDIATE :script;
  RETURN 'Step 5 Complete: Dimension tables created';
END;
$$;

/*******************************************************************************
 * STEP 6: Create Fact Table
 ******************************************************************************/

EXECUTE IMMEDIATE $$
DECLARE
  script STRING;
BEGIN
  SELECT file_content
  INTO :script
  FROM TABLE(
    READ_GIT_FILE(
      repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
      file_path => 'sql/01_setup/06_fact_table.sql',
      ref => 'main'
    )
  );
  
  EXECUTE IMMEDIATE :script;
  RETURN 'Step 6 Complete: FCT_ACCESS_EVENTS table created';
END;
$$;

/*******************************************************************************
 * STEP 7: Create Stream (CDC)
 ******************************************************************************/

EXECUTE IMMEDIATE $$
DECLARE
  script STRING;
BEGIN
  SELECT file_content
  INTO :script
  FROM TABLE(
    READ_GIT_FILE(
      repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
      file_path => 'sql/01_setup/07_stream.sql',
      ref => 'main'
    )
  );
  
  EXECUTE IMMEDIATE :script;
  RETURN 'Step 7 Complete: sfe_badge_events_stream created';
END;
$$;

/*******************************************************************************
 * STEP 8: Create Tasks (Incremental Processing)
 ******************************************************************************/

EXECUTE IMMEDIATE $$
DECLARE
  script STRING;
BEGIN
  SELECT file_content
  INTO :script
  FROM TABLE(
    READ_GIT_FILE(
      repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
      file_path => 'sql/01_setup/08_tasks.sql',
      ref => 'main'
    )
  );
  
  EXECUTE IMMEDIATE :script;
  RETURN 'Step 8 Complete: Tasks created and resumed';
END;
$$;

/*******************************************************************************
 * STEP 9: Create Monitoring Views
 ******************************************************************************/

EXECUTE IMMEDIATE $$
DECLARE
  script STRING;
BEGIN
  SELECT file_content
  INTO :script
  FROM TABLE(
    READ_GIT_FILE(
      repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
      file_path => 'sql/03_monitoring/monitoring_views.sql',
      ref => 'main'
    )
  );
  
  EXECUTE IMMEDIATE :script;
  RETURN 'Step 9 Complete: Monitoring views created';
END;
$$;

/*******************************************************************************
 * SUCCESS CHECKPOINT - Verify Deployment
 ******************************************************************************/

-- Verify database objects
SELECT 'Databases' AS object_type, COUNT(*) AS count 
FROM INFORMATION_SCHEMA.DATABASES 
WHERE DATABASE_NAME = 'SNOWFLAKE_EXAMPLE'
UNION ALL
SELECT 'Schemas', COUNT(*) 
FROM INFORMATION_SCHEMA.SCHEMATA 
WHERE SCHEMA_NAME IN ('RAW_INGESTION', 'STAGING_LAYER', 'ANALYTICS_LAYER', 'DEMO_REPO')
UNION ALL
SELECT 'Tables', COUNT(*) 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA IN ('RAW_INGESTION', 'STAGING_LAYER', 'ANALYTICS_LAYER')
  AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'Views', COUNT(*) 
FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA IN ('RAW_INGESTION', 'STAGING_LAYER', 'ANALYTICS_LAYER');

-- Verify pipes (should show sfe_badge_events_pipe)
SHOW PIPES LIKE 'sfe_%' IN SCHEMA RAW_INGESTION;

-- Verify streams (should show sfe_badge_events_stream)
SHOW STREAMS LIKE 'sfe_%' IN DATABASE SNOWFLAKE_EXAMPLE;

-- Verify tasks (should show sfe_raw_to_staging_task, sfe_staging_to_analytics_task)
SHOW TASKS LIKE 'sfe_%' IN DATABASE SNOWFLAKE_EXAMPLE;

/*******************************************************************************
 * EXPECTED RESULTS:
 *   - 1 Database: SNOWFLAKE_EXAMPLE
 *   - 4 Schemas: RAW_INGESTION, STAGING_LAYER, ANALYTICS_LAYER, DEMO_REPO
 *   - 9 Tables: RAW_BADGE_EVENTS, STG_BADGE_EVENTS, STG_DIM_USERS, STG_DIM_ZONES, 
 *               STG_DIM_READERS, DIM_USERS, DIM_ZONES, DIM_READERS, FCT_ACCESS_EVENTS
 *   - 1 Pipe: sfe_badge_events_pipe (state: running)
 *   - 1 Stream: sfe_badge_events_stream
 *   - 2 Tasks: sfe_raw_to_staging_task (state: started), 
 *              sfe_staging_to_analytics_task (state: started)
 *   - Multiple monitoring views
 * 
 * NEXT STEPS:
 *   ✅ Pipeline deployed successfully!
 * 
 *   → Option 1: Run simulator in Snowflake Notebook
 *     1. Open notebooks/RFID_Simulator.ipynb in Snowsight
 *     2. Execute all cells
 *     3. Watch data flow through the pipeline in real-time
 * 
 *   → Option 2: Use stored procedure for validation
 *     CALL SNOWFLAKE_EXAMPLE.DEMO_REPO.SFE_VALIDATE_PIPELINE();
 * 
 *   → Option 3: Send test events via curl
 *     See docs/REST_API_GUIDE.md for curl examples
 * 
 *   → Monitor the pipeline:
 *     SELECT * FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.V_PIPELINE_HEALTH;
 * 
 * TROUBLESHOOTING:
 *   - If tasks not running: ALTER TASK <name> RESUME;
 *   - If pipe not running: ALTER PIPE <name> REFRESH;
 *   - View task history: SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY());
 *   - Check stream status: SHOW STREAMS LIKE 'sfe_%' IN DATABASE SNOWFLAKE_EXAMPLE;
 ******************************************************************************/
