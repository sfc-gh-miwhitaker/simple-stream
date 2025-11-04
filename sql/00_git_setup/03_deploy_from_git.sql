/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Deploy from Git
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Execute setup scripts stored in the Git repository.
 * OBJECTS: Full pipeline (schemas, tables, stream, tasks, monitoring views)
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

USE ROLE SYSADMIN;
USE DATABASE SNOWFLAKE_EXAMPLE;

EXECUTE IMMEDIATE $$
DECLARE
    files ARRAY;
    idx INTEGER;
    script STRING;
BEGIN
    files := ARRAY_CONSTRUCT(
        'sql/01_setup/01_database_and_schemas.sql',
        'sql/01_setup/02_raw_table.sql',
        'sql/01_setup/03_pipe_object.sql',
        'sql/01_setup/04_staging_table.sql',
        'sql/01_setup/05_dimension_tables.sql',
        'sql/01_setup/06_fact_table.sql',
        'sql/01_setup/07_stream.sql',
        'sql/01_setup/08_tasks.sql',
        'sql/03_monitoring/monitoring_views.sql'
    );

    FOR idx IN 0 .. ARRAY_SIZE(files) - 1 DO
        SELECT file_content
        INTO :script
        FROM TABLE(
            READ_GIT_FILE(
                repository => 'SNOWFLAKE_EXAMPLE.DEMO_REPO.sfe_simple_stream_repo',
                file_path => files[idx],
                ref => 'main'
            )
        );

        EXECUTE IMMEDIATE :script;
    END FOR;
END;
$$;
