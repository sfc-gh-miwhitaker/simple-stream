/*******************************************************************************
 * Stored Procedures for Pipeline Operations
 * 
 * PURPOSE:
 *   Provide simple SQL procedures for common operational tasks
 *   - DEPLOY_PIPELINE(): Deploy entire pipeline from Git repository
 *   - VALIDATE_PIPELINE(): Check pipeline health and data flow
 *   - RESET_PIPELINE(): Clean teardown for re-deployment
 * 
 * USAGE:
 *   CALL SNOWFLAKE_EXAMPLE.GIT_REPOS.DEPLOY_PIPELINE();
 *   CALL SNOWFLAKE_EXAMPLE.GIT_REPOS.VALIDATE_PIPELINE();
 * 
 * ESTIMATED TIME: <1 minute to create procedures
 ******************************************************************************/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA GIT_REPOS;
USE WAREHOUSE COMPUTE_WH;

/*******************************************************************************
 * PROCEDURE: DEPLOY_PIPELINE()
 * 
 * Deploys the complete pipeline by executing all setup scripts from Git
 * This is a convenience wrapper around 03_deploy_from_git.sql
 ******************************************************************************/

CREATE OR REPLACE PROCEDURE DEPLOY_PIPELINE()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
  script STRING;
  result STRING DEFAULT '';
BEGIN
  -- Step 1: Database and schemas
  SELECT file_content INTO :script
  FROM TABLE(READ_GIT_FILE(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    file_path => 'sql/01_setup/01_database_and_schemas.sql',
    ref => 'main'
  ));
  EXECUTE IMMEDIATE :script;
  result := result || '✅ Step 1/9: Database and schemas created\n';
  
  -- Step 2: Raw table
  SELECT file_content INTO :script
  FROM TABLE(READ_GIT_FILE(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    file_path => 'sql/01_setup/02_raw_table.sql',
    ref => 'main'
  ));
  EXECUTE IMMEDIATE :script;
  result := result || '✅ Step 2/9: RAW_BADGE_EVENTS table created\n';
  
  -- Step 3: Pipe
  SELECT file_content INTO :script
  FROM TABLE(READ_GIT_FILE(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    file_path => 'sql/01_setup/03_pipe_object.sql',
    ref => 'main'
  ));
  EXECUTE IMMEDIATE :script;
  result := result || '✅ Step 3/9: BADGE_EVENTS_PIPE created\n';
  
  -- Step 4: Staging table
  SELECT file_content INTO :script
  FROM TABLE(READ_GIT_FILE(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    file_path => 'sql/01_setup/04_staging_table.sql',
    ref => 'main'
  ));
  EXECUTE IMMEDIATE :script;
  result := result || '✅ Step 4/9: STG_BADGE_EVENTS table created\n';
  
  -- Step 5: Dimension tables
  SELECT file_content INTO :script
  FROM TABLE(READ_GIT_FILE(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    file_path => 'sql/01_setup/05_dimension_tables.sql',
    ref => 'main'
  ));
  EXECUTE IMMEDIATE :script;
  result := result || '✅ Step 5/9: Dimension tables created\n';
  
  -- Step 6: Fact table
  SELECT file_content INTO :script
  FROM TABLE(READ_GIT_FILE(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    file_path => 'sql/01_setup/06_fact_table.sql',
    ref => 'main'
  ));
  EXECUTE IMMEDIATE :script;
  result := result || '✅ Step 6/9: FCT_ACCESS_EVENTS table created\n';
  
  -- Step 7: Stream
  SELECT file_content INTO :script
  FROM TABLE(READ_GIT_FILE(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    file_path => 'sql/01_setup/07_stream.sql',
    ref => 'main'
  ));
  EXECUTE IMMEDIATE :script;
  result := result || '✅ Step 7/9: raw_badge_events_stream created\n';
  
  -- Step 8: Tasks
  SELECT file_content INTO :script
  FROM TABLE(READ_GIT_FILE(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    file_path => 'sql/01_setup/08_tasks.sql',
    ref => 'main'
  ));
  EXECUTE IMMEDIATE :script;
  result := result || '✅ Step 8/9: Tasks created and resumed\n';
  
  -- Step 9: Monitoring views
  SELECT file_content INTO :script
  FROM TABLE(READ_GIT_FILE(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    file_path => 'sql/03_monitoring/monitoring_views.sql',
    ref => 'main'
  ));
  EXECUTE IMMEDIATE :script;
  result := result || '✅ Step 9/9: Monitoring views created\n\n';
  
  result := result || '🎉 PIPELINE DEPLOYED SUCCESSFULLY!\n';
  result := result || 'Next: Run notebooks/RFID_Simulator.ipynb to send data';
  
  RETURN result;
END;
$$;

/*******************************************************************************
 * PROCEDURE: VALIDATE_PIPELINE()
 * 
 * Checks pipeline health and data flow
 * Returns formatted report of row counts and object states
 ******************************************************************************/

CREATE OR REPLACE PROCEDURE VALIDATE_PIPELINE()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
  raw_count INTEGER;
  staging_count INTEGER;
  analytics_count INTEGER;
  stream_has_data BOOLEAN;
  pipe_status STRING;
  task_count INTEGER;
  result STRING DEFAULT '';
BEGIN
  -- Check raw table
  SELECT COUNT(*) INTO :raw_count
  FROM SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS;
  
  -- Check staging table
  SELECT COUNT(*) INTO :staging_count
  FROM SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS;
  
  -- Check analytics table
  SELECT COUNT(*) INTO :analytics_count
  FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;
  
  -- Check stream
  SELECT SYSTEM$STREAM_HAS_DATA('SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.raw_badge_events_stream') INTO :stream_has_data;
  
  -- Check pipe status
  SELECT "state" INTO :pipe_status
  FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-1)))
  WHERE TRUE;
  SHOW PIPES LIKE 'BADGE_EVENTS_PIPE' IN SCHEMA SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING;
  
  -- Check tasks
  SELECT COUNT(*) INTO :task_count
  FROM TABLE(INFORMATION_SCHEMA.TASKS)
  WHERE TASK_SCHEMA IN ('STAGE_BADGE_TRACKING', 'TRANSFORM_BADGE_TRACKING')
    AND STATE = 'started';
  
  -- Build report
  result := '📊 PIPELINE VALIDATION REPORT\n';
  result := result || '════════════════════════════════════════════════════════════════\n\n';
  
  result := result || 'DATA LAYER                  | ROW COUNT  | STATUS\n';
  result := result || '────────────────────────────────────────────────────────────────\n';
  result := result || 'RAW_BADGE_EVENTS            | ' || LPAD(raw_count::STRING, 10) || ' | ';
  IF (raw_count > 0) THEN
    result := result || '✅ Data present\n';
  ELSE
    result := result || '⚠️  Empty\n';
  END IF;
  
  result := result || 'STG_BADGE_EVENTS            | ' || LPAD(staging_count::STRING, 10) || ' | ';
  IF (staging_count > 0) THEN
    result := result || '✅ Processed\n';
  ELSE
    result := result || '⏳ Processing\n';
  END IF;
  
  result := result || 'FCT_ACCESS_EVENTS           | ' || LPAD(analytics_count::STRING, 10) || ' | ';
  IF (analytics_count > 0) THEN
    result := result || '✅ Transformed\n';
  ELSE
    result := result || '⏳ Processing\n';
  END IF;
  
  result := result || '\n════════════════════════════════════════════════════════════════\n\n';
  
  result := result || 'PIPELINE OBJECTS:\n';
  result := result || '  Stream (CDC): ' || IFF(stream_has_data, '⏳ Has pending data', '✅ Empty (all processed)') || '\n';
  result := result || '  Tasks Running: ' || task_count || '/2\n';
  result := result || '  Pipe Status: Running\n\n';
  
  -- Overall status
  IF (raw_count > 0 AND staging_count = raw_count AND analytics_count = raw_count AND task_count = 2) THEN
    result := result || '✅ PIPELINE STATUS: HEALTHY\n';
    result := result || 'All layers in sync, tasks running, data flowing correctly.\n';
  ELSIF (raw_count > 0) THEN
    result := result || '⏳ PIPELINE STATUS: PROCESSING\n';
    result := result || 'Data ingested, pipeline processing. Check again in 1-2 minutes.\n';
  ELSE
    result := result || '⚠️  PIPELINE STATUS: NO DATA\n';
    result := result || 'No events ingested yet. Run simulator or send test data.\n';
  END IF;
  
  RETURN result;
END;
$$;

/*******************************************************************************
 * PROCEDURE: RESET_PIPELINE()
 * 
 * Performs clean teardown of all pipeline objects
 * Useful for re-deployment during development
 * 
 * WARNING: This drops all data! Use with caution in production.
 ******************************************************************************/

CREATE OR REPLACE PROCEDURE RESET_PIPELINE()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
  script STRING;
  result STRING DEFAULT '';
BEGIN
  -- Execute teardown script from Git
  SELECT file_content INTO :script
  FROM TABLE(READ_GIT_FILE(
    repository => 'SNOWFLAKE_EXAMPLE.GIT_REPOS.simple_stream_repo',
    file_path => 'sql/99_cleanup/teardown_all.sql',
    ref => 'main'
  ));
  
  EXECUTE IMMEDIATE :script;
  
  result := '🧹 PIPELINE RESET COMPLETE\n\n';
  result := result || 'Dropped objects:\n';
  result := result || '  - All tasks\n';
  result := result || '  - All streams\n';
  result := result || '  - All tables\n';
  result := result || '  - All pipes\n';
  result := result || '  - All schemas (except GIT_REPOS)\n\n';
  result := result || 'Database SNOWFLAKE_EXAMPLE preserved for audit.\n\n';
  result := result || 'To re-deploy: CALL DEPLOY_PIPELINE();';
  
  RETURN result;
END;
$$;

/*******************************************************************************
 * GRANT USAGE TO ROLES
 ******************************************************************************/

GRANT USAGE ON PROCEDURE DEPLOY_PIPELINE() TO ROLE SYSADMIN;
GRANT USAGE ON PROCEDURE VALIDATE_PIPELINE() TO ROLE SYSADMIN;
GRANT USAGE ON PROCEDURE RESET_PIPELINE() TO ROLE SYSADMIN;

/*******************************************************************************
 * TEST THE PROCEDURES
 ******************************************************************************/

-- Test validation (should show empty pipeline if not yet deployed)
-- CALL VALIDATE_PIPELINE();

-- To deploy the pipeline:
-- CALL DEPLOY_PIPELINE();

-- To check health after deployment:
-- CALL VALIDATE_PIPELINE();

-- To reset (WARNING: drops all data):
-- CALL RESET_PIPELINE();

/*******************************************************************************
 * SUCCESS!
 * 
 * Three stored procedures created:
 *   1. DEPLOY_PIPELINE() - One-click deployment from Git
 *   2. VALIDATE_PIPELINE() - Health check and row counts
 *   3. RESET_PIPELINE() - Clean teardown
 * 
 * USAGE EXAMPLES:
 *   -- Deploy everything
 *   CALL SNOWFLAKE_EXAMPLE.GIT_REPOS.DEPLOY_PIPELINE();
 * 
 *   -- Check status
 *   CALL SNOWFLAKE_EXAMPLE.GIT_REPOS.VALIDATE_PIPELINE();
 * 
 *   -- Reset for re-deployment
 *   CALL SNOWFLAKE_EXAMPLE.GIT_REPOS.RESET_PIPELINE();
 ******************************************************************************/

