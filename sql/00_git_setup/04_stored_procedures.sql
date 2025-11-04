/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Pipeline Procedures
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Create helper procedures for deploy, validate, and reset.
 * OBJECTS: SFE_DEPLOY_PIPELINE, SFE_VALIDATE_PIPELINE, SFE_RESET_PIPELINE
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA DEMO_REPO;

CREATE OR REPLACE PROCEDURE SFE_DEPLOY_PIPELINE()
RETURNS STRING
LANGUAGE SQL
COMMENT = 'DEMO: sfe-simple-stream - Automated deployment from Git repository'
EXECUTE AS CALLER
AS
$$
DECLARE
    script STRING;
BEGIN
    SELECT file_content INTO :script
    FROM TABLE(READ_GIT_FILE(
        repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
        file_path => 'sql/00_git_setup/03_deploy_from_git.sql',
        ref => 'main'
    ));

    EXECUTE IMMEDIATE :script;
    RETURN 'DEPLOYED';
END;
$$;

CREATE OR REPLACE PROCEDURE SFE_VALIDATE_PIPELINE()
RETURNS VARIANT
LANGUAGE SQL
COMMENT = 'DEMO: sfe-simple-stream - Pipeline health check summary'
EXECUTE AS CALLER
AS
$$
DECLARE
    report VARIANT;
BEGIN
    report := OBJECT_CONSTRUCT(
        'raw_rows', (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.RAW_INGESTION.RAW_BADGE_EVENTS),
        'staging_rows', (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.STAGING_LAYER.STG_BADGE_EVENTS),
        'fact_rows', (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.FCT_ACCESS_EVENTS),
        'stream_has_data', SYSTEM$STREAM_HAS_DATA('SNOWFLAKE_EXAMPLE.RAW_INGESTION.sfe_badge_events_stream'),
        'tasks_running', (
            SELECT COUNT(*)
            FROM SNOWFLAKE_EXAMPLE.INFORMATION_SCHEMA.TASKS
            WHERE TASK_SCHEMA IN ('RAW_INGESTION', 'STAGING_LAYER')
              AND STATE = 'started'
        )
    );

    RETURN report;
END;
$$;

CREATE OR REPLACE PROCEDURE SFE_RESET_PIPELINE()
RETURNS STRING
LANGUAGE SQL
COMMENT = 'DEMO: sfe-simple-stream - Clean teardown for re-deployment'
EXECUTE AS CALLER
AS
$$
DECLARE
    script STRING;
BEGIN
    SELECT file_content INTO :script
    FROM TABLE(READ_GIT_FILE(
        repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
        file_path => 'sql/99_cleanup/teardown_all.sql',
        ref => 'main'
    ));

    EXECUTE IMMEDIATE :script;
    RETURN 'RESET';
END;
$$;

GRANT USAGE ON PROCEDURE SFE_DEPLOY_PIPELINE() TO ROLE SYSADMIN;
GRANT USAGE ON PROCEDURE SFE_VALIDATE_PIPELINE() TO ROLE SYSADMIN;
GRANT USAGE ON PROCEDURE SFE_RESET_PIPELINE() TO ROLE SYSADMIN;
