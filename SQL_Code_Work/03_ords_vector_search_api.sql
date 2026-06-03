-- Oracle AI Database: Exposing Vector Search via ORDS
-- This script demonstrates how to create a REST API endpoint that 
-- accepts a query vector and returns the most similar articles.

-- 1. Enable ORDS for the schema (if not already enabled)
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => 'MY_USER',
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'ai_api',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/

-- 2. Define a REST Module for AI Services
BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'ai.v1',
        p_base_path      => 'v1/',
        p_items_per_page => 0,
        p_status         => 'PUBLISHED',
        p_comments       => 'AI-powered REST Services'
    );
    COMMIT;
END;
/

-- 3. Define a Template for Vector Search
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'ai.v1',
        p_pattern     => 'search/vector'
    );
    COMMIT;
END;
/

-- 4. Define a POST Handler that accepts a vector in the body
-- The handler takes a JSON input like: {"query_vector": "[0.1, 0.8, 0.2]"}
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ai.v1',
        p_pattern     => 'search/vector',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_collection_feed,
        p_source      => 'SELECT title, 
                             VECTOR_DISTANCE(v_content, :query_vector, COSINE) as distance
                      FROM tech_articles
                      ORDER BY distance
                      FETCH FIRST 5 ROWS ONLY',
        p_items_per_page => 0
    );
    COMMIT;
END;
/

-- Example Usage (via curl):
-- curl -X POST http://localhost:8080/ords/ai_api/v1/search/vector \
--      -H "Content-Type: application/json" \
--      -d '{"query_vector": "[0.15, 0.75, 0.25]"}'
