/*******************************************************************************
 * DEMO PROJECT: sfe-simple-stream
 * Script: Fact Table Creation
 * 
 * ⚠️  NOT FOR PRODUCTION USE - EXAMPLE IMPLEMENTATION ONLY
 * 
 * PURPOSE:
 *   Create the fact table for access events with clustering for optimal
 *   query performance on time-series data.
 * 
 * OBJECTS CREATED:
 *   - FCT_ACCESS_EVENTS: Access event fact table with time dimensions
 * 
 * KEY FEATURES:
 *   - Clustered by event_date for time-series query optimization
 *   - Foreign key relationships to dimension tables
 *   - Pre-calculated flags (after_hours, weekend, restricted)
 *   - Degenerate dimensions (badge_id, reader_id)
 * 
 * TARGET: SNOWFLAKE_EXAMPLE.ANALYTICS_LAYER.FCT_ACCESS_EVENTS
 * SOURCE: STAGING_LAYER.STG_BADGE_EVENTS joined with dimension tables
 * 
 * CLEANUP:
 *   See sql/99_cleanup/teardown_all.sql for complete removal
 ******************************************************************************/

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA ANALYTICS_LAYER;

/*******************************************************************************
 * FCT_ACCESS_EVENTS: Access Event Fact Table
 * 
 * Star schema fact table with time-series optimization
 ******************************************************************************/

CREATE OR REPLACE TABLE FCT_ACCESS_EVENTS (
    -- Surrogate key
    event_key NUMBER AUTOINCREMENT PRIMARY KEY COMMENT 'Surrogate key for event fact',
    
    -- Dimension foreign keys
    user_key NUMBER NOT NULL COMMENT 'Foreign key to DIM_USERS',
    zone_key NUMBER NOT NULL COMMENT 'Foreign key to DIM_ZONES',
    
    -- Degenerate dimensions (attributes carried in fact)
    badge_id VARCHAR(50) NOT NULL COMMENT 'Badge identifier',
    reader_id VARCHAR(50) NOT NULL COMMENT 'Reader identifier',
    
    -- Date/Time dimensions
    event_timestamp TIMESTAMP_NTZ NOT NULL COMMENT 'When event occurred',
    event_date DATE NOT NULL COMMENT 'Event date (for clustering)',
    event_hour NUMBER(2) NOT NULL COMMENT 'Hour of day (0-23)',
    event_day_of_week NUMBER(1) NOT NULL COMMENT 'Day of week (0=Sunday)',
    
    -- Event attributes
    direction VARCHAR(10) COMMENT 'ENTRY, EXIT, or null',
    
    -- Measures/Metrics
    signal_strength NUMBER(5, 2) COMMENT 'Signal strength in dBm',
    signal_quality VARCHAR(10) COMMENT 'WEAK, MEDIUM, STRONG',
    
    -- Flags for analytics (pre-calculated for performance)
    is_restricted_access BOOLEAN COMMENT 'Was this a restricted zone access',
    is_after_hours BOOLEAN COMMENT 'Did event occur outside business hours (before 6am or after 10pm)',
    is_weekend BOOLEAN COMMENT 'Did event occur on weekend',
    
    -- Audit columns
    ingestion_time TIMESTAMP_NTZ NOT NULL COMMENT 'When raw event was ingested',
    fact_load_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'When fact record was created',
    
    -- Foreign key constraints
    CONSTRAINT fk_fct_user FOREIGN KEY (user_key) REFERENCES DIM_USERS(user_key),
    CONSTRAINT fk_fct_zone FOREIGN KEY (zone_key) REFERENCES DIM_ZONES(zone_key)
)
COMMENT = 'DEMO: sfe-simple-stream - Fact table for RFID badge access events with time-series optimization'
CLUSTER BY (event_date);  -- Cluster by date for time-series query performance

/*******************************************************************************
 * Verification Queries
 ******************************************************************************/

-- Display table structure
DESCRIBE TABLE FCT_ACCESS_EVENTS;

-- Verify clustering configuration
SHOW TABLES LIKE 'FCT_ACCESS_EVENTS' IN SCHEMA ANALYTICS_LAYER;

-- Check table is empty (no data loaded yet)
SELECT COUNT(*) AS row_count FROM FCT_ACCESS_EVENTS;

/*******************************************************************************
 * CLUSTERING STRATEGY EXPLAINED
 * 
 * We cluster on event_date (not event_timestamp) because:
 *   1. Most queries filter by date ranges (WHERE event_date BETWEEN...)
 *   2. Date has lower cardinality than timestamp → better clustering
 *   3. Reduces micro-partition scanning for date-based queries
 *   4. Optimal for time-series analytics
 * 
 * This follows the architectural principle: cluster on the lowest cardinality
 * column that appears in WHERE clauses.
 * 
 * BAD: CLUSTER BY (event_timestamp)  -- Too high cardinality
 * BAD: CLUSTER BY (user_key)         -- Not used in most queries
 * GOOD: CLUSTER BY (event_date)      -- Perfect balance
 * 
 * For composite keys, order matters:
 *   CLUSTER BY (event_date, zone_key)  -- Good if filtering by both
 ******************************************************************************/

/*******************************************************************************
 * OPTIMAL QUERY PATTERNS
 * 
 * 1. Time-series queries (leverages clustering):
 *    SELECT * FROM FCT_ACCESS_EVENTS 
 *    WHERE event_date BETWEEN '2024-01-01' AND '2024-01-31';
 * 
 * 2. User access history:
 *    SELECT e.*, u.user_name, z.zone_name
 *    FROM FCT_ACCESS_EVENTS e
 *    JOIN DIM_USERS u ON e.user_key = u.user_key
 *    JOIN DIM_ZONES z ON e.zone_key = z.zone_key
 *    WHERE e.badge_id = 'BADGE-12345'
 *      AND e.event_date >= CURRENT_DATE() - 7;
 * 
 * 3. Zone occupancy tracking:
 *    SELECT zone_key, COUNT(*) as entry_count
 *    FROM FCT_ACCESS_EVENTS
 *    WHERE event_date = CURRENT_DATE()
 *      AND direction = 'ENTRY'
 *    GROUP BY zone_key;
 * 
 * 4. After-hours access alerts (uses pre-calculated flag):
 *    SELECT * FROM FCT_ACCESS_EVENTS
 *    WHERE is_after_hours = TRUE
 *      AND is_restricted_access = TRUE
 *      AND event_date = CURRENT_DATE();
 * 
 * 5. Weekend restricted access report:
 *    SELECT 
 *      u.user_name,
 *      z.zone_name,
 *      COUNT(*) AS access_count
 *    FROM FCT_ACCESS_EVENTS e
 *    JOIN DIM_USERS u ON e.user_key = u.user_key
 *    JOIN DIM_ZONES z ON e.zone_key = z.zone_key
 *    WHERE e.is_weekend = TRUE
 *      AND e.is_restricted_access = TRUE
 *      AND e.event_date >= CURRENT_DATE() - 30
 *    GROUP BY 1, 2
 *    ORDER BY access_count DESC;
 ******************************************************************************/

/*******************************************************************************
 * MONITORING CLUSTERING HEALTH
 * 
 * Check clustering effectiveness:
 *   SELECT SYSTEM$CLUSTERING_INFORMATION('FCT_ACCESS_EVENTS');
 * 
 * Monitor clustering depth (lower is better, typically < 5 is good):
 *   SELECT SYSTEM$CLUSTERING_DEPTH('FCT_ACCESS_EVENTS');
 * 
 * View clustering history:
 *   SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY
 *   WHERE TABLE_NAME = 'FCT_ACCESS_EVENTS'
 *   ORDER BY START_TIME DESC;
 ******************************************************************************/
