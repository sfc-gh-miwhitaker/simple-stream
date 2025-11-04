/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream | Script: Fact Table
 * ⚠️ NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * PURPOSE: Create clustered fact table for access events.
 * OBJECTS: FCT_ACCESS_EVENTS
 * CLEANUP: sql/99_cleanup/teardown_all.sql
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA ANALYTICS_LAYER;

CREATE OR REPLACE TABLE FCT_ACCESS_EVENTS (
    event_key NUMBER AUTOINCREMENT PRIMARY KEY,
    user_key NUMBER NOT NULL,
    zone_key NUMBER NOT NULL,
    badge_id VARCHAR(50) NOT NULL,
    reader_id VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMP_NTZ NOT NULL,
    event_date DATE NOT NULL,
    event_hour NUMBER(2) NOT NULL,
    event_day_of_week NUMBER(1) NOT NULL,
    direction VARCHAR(10),
    signal_strength NUMBER(5, 2),
    signal_quality VARCHAR(10),
    is_restricted_access BOOLEAN,
    is_after_hours BOOLEAN,
    is_weekend BOOLEAN,
    ingestion_time TIMESTAMP_NTZ NOT NULL,
    fact_load_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT fk_fct_user FOREIGN KEY (user_key) REFERENCES DIM_USERS(user_key),
    CONSTRAINT fk_fct_zone FOREIGN KEY (zone_key) REFERENCES DIM_ZONES(zone_key)
)
COMMENT = 'DEMO: sfe-simple-stream - Fact table for badge access events'
CLUSTER BY (event_date);
