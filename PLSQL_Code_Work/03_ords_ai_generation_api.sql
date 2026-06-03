-- Oracle AI Database: AI-Driven Text Generation via ORDS
-- This script demonstrates how to expose a PL/SQL procedure that 
-- uses DBMS_CLOUD_AI as a REST API endpoint.

-- 1. Define a Template for AI Generation
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'ai.v1',
        p_pattern     => 'generate/text'
    );
    COMMIT;
END;
/

-- 2. Define a POST Handler that calls DBMS_CLOUD_AI
-- This handler takes a JSON input like: {"prompt": "Summarize Oracle 26ai features"}
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ai.v1',
        p_pattern     => 'generate/text',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => 'DECLARE
                            l_response CLOB;
                          BEGIN
                            l_response := DBMS_CLOUD_AI.GENERATE(
                                profile_name => ''GENAI_PROFILE'',
                                prompt       => :prompt,
                                action       => ''GENERATE_TEXT''
                            );
                            
                            -- Send the response back as JSON
                            OWA_UTIL.MIME_HEADER(''application/json'', TRUE);
                            HTP.P(''{"ai_response": "'' || REPLACE(l_response, ''"'', ''\"'') || ''"}'');
                          END;',
        p_items_per_page => 0
    );
    COMMIT;
END;
/

-- 3. Define a Template for Natural Language to SQL
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'ai.v1',
        p_pattern     => 'query/nl'
    );
    COMMIT;
END;
/

-- 4. Define a POST Handler for NL to SQL
-- This handler takes a JSON input like: {"nl_query": "how many articles were published?"}
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ai.v1',
        p_pattern     => 'query/nl',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source      => 'DECLARE
                            l_sql VARCHAR2(4000);
                          BEGIN
                            l_sql := DBMS_CLOUD_AI.GENERATE(
                                profile_name => ''GENAI_PROFILE'',
                                prompt       => :nl_query,
                                action       => ''SHOWSQL''
                            );
                            
                            -- Send the generated SQL back as JSON
                            OWA_UTIL.MIME_HEADER(''application/json'', TRUE);
                            HTP.P(''{"generated_sql": "'' || REPLACE(l_sql, ''"'', ''\"'') || ''"}'');
                          END;',
        p_items_per_page => 0
    );
    COMMIT;
END;
/

-- Example Usage (via curl):
-- curl -X POST http://localhost:8080/ords/ai_api/v1/generate/text \
--      -H "Content-Type: application/json" \
--      -d '{"prompt": "Write a short poem about databases"}'
