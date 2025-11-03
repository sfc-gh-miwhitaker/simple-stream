/*******************************************************************************
 * Deploy Pipeline from Git Repository
 * 
 * PURPOSE:
 *   Execute SQL scripts from the cloned Git repository to deploy the full pipeline
 *   This replaces the need to run local deployment scripts
 * 
 * ARCHITECTURE:
 *   SNOWFLAKE_EXAMPLE (database)
 *   ├── STAGE_BADGE_TRACKING (schema)     - Raw ingestion layer
 *   │   ├── RAW_BADGE_EVENTS (table)      - Snowpipe Streaming target
 *   │   ├── BADGE_EVENTS_PIPE (pipe)      - REST API endpoint
 *   │   └── raw_badge_events_stream       - CDC stream
 *   ├── TRANSFORM_BADGE_TRACKING          - Staging/transformation layer
 *   │   ├── STG_BADGE_EVENTS
 *   │   ├── STG_DIM_USERS
 *   │   ├── STG_DIM_ZONES
 *   │   └── STG_DIM_READERS
 *   └── ANALYTICS_BADGE_TRACKING          - Analytics layer
 *       ├── DIM_USERS
 *       ├── DIM_ZONES
 *       ├── DIM_READERS
 *       └── FCT_ACCESS_EVENTS
 * 
 * PREREQUISITES:
 *   - sql/00_git_setup/01_git_repository_setup.sql executed
 *   - sql/00_git_setup/02_configure_secrets.sql executed
 * 
 * USAGE:
 *   Execute this entire file in a Snowflake worksheet
 * 
 * ESTIMATED TIME: 2-3 minutes
 ******************************************************************************/

-- Set context
USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;  -- Use default warehouse (or create/specify your own)
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
      repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
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
      repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
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
      repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
      file_path => 'sql/01_setup/03_pipe_object.sql',
      ref => 'main'
    )
  );
  
  EXECUTE IMMEDIATE :script;
  RETURN 'Step 3 Complete: BADGE_EVENTS_PIPE created';
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
      repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
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
      repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
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
      repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
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
      repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
      file_path => 'sql/01_setup/07_stream.sql',
      ref => 'main'
    )
  );
  
  EXECUTE IMMEDIATE :script;
  RETURN 'Step 7 Complete: raw_badge_events_stream created';
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
      repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
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
      repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
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
WHERE SCHEMA_NAME IN ('STAGE_BADGE_TRACKING', 'TRANSFORM_BADGE_TRACKING', 'ANALYTICS_BADGE_TRACKING')
UNION ALL
SELECT 'Tables', COUNT(*) 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA IN ('STAGE_BADGE_TRACKING', 'TRANSFORM_BADGE_TRACKING', 'ANALYTICS_BADGE_TRACKING')
  AND TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT 'Views', COUNT(*) 
FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA IN ('STAGE_BADGE_TRACKING', 'TRANSFORM_BADGE_TRACKING', 'ANALYTICS_BADGE_TRACKING');

-- Verify pipes
SHOW PIPES IN SCHEMA STAGE_BADGE_TRACKING;

-- Verify streams
SHOW STREAMS IN DATABASE SNOWFLAKE_EXAMPLE;

-- Verify tasks (should show 2 tasks: process_raw_to_staging, process_staging_to_analytics)
SHOW TASKS IN DATABASE SNOWFLAKE_EXAMPLE;

/*******************************************************************************
 * EXPECTED RESULTS:
 *   - 1 Database: SNOWFLAKE_EXAMPLE
 *   - 3 Schemas: STAGE_BADGE_TRACKING, TRANSFORM_BADGE_TRACKING, ANALYTICS_BADGE_TRACKING
 *   - 9 Tables: RAW_BADGE_EVENTS, STG_BADGE_EVENTS, STG_DIM_USERS, STG_DIM_ZONES, 
 *               STG_DIM_READERS, DIM_USERS, DIM_ZONES, DIM_READERS, FCT_ACCESS_EVENTS
 *   - 1 Pipe: BADGE_EVENTS_PIPE (state: running)
 *   - 1 Stream: raw_badge_events_stream
 *   - 2 Tasks: process_raw_to_staging (state: started), process_staging_to_analytics (state: started)
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
 *   → Option 2: Send test events via curl
 *     See README.md#tldr for curl examples
 * 
 *   → Monitor the pipeline:
 *     SELECT * FROM SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.V_PIPELINE_HEALTH;
 * 
 * TROUBLESHOOTING:
 *   - If tasks not running: ALTER TASK <name> RESUME;
 *   - If pipe not running: ALTER PIPE <name> REFRESH;
 *   - View task history: SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY());
 ******************************************************************************/

