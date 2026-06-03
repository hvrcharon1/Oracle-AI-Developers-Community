-- Oracle AI Database: AI Agent Workflow
-- This package demonstrates a simple agentic workflow using DBMS_CLOUD_AI.

CREATE OR REPLACE PACKAGE ai_agent_pkg AS
    -- Main procedure to process a user request through an AI agent
    PROCEDURE process_request(p_request IN VARCHAR2);
END ai_agent_pkg;
/

CREATE OR REPLACE PACKAGE BODY ai_agent_pkg AS

    PROCEDURE process_request(p_request IN VARCHAR2) IS
        l_response CLOB;
        l_sql      VARCHAR2(4000);
    BEGIN
        DBMS_OUTPUT.PUT_LINE('User Request: ' || p_request);
        
        -- 1. Use AI to determine if we need to query data or just chat
        l_response := DBMS_CLOUD_AI.GENERATE(
            profile_name => 'GENAI_PROFILE',
            prompt       => 'Categorize this request as QUERY or CHAT: ' || p_request,
            action       => 'GENERATE_TEXT'
        );

        IF l_response LIKE '%QUERY%' THEN
            -- 2. If it's a query, generate the SQL
            l_sql := DBMS_CLOUD_AI.GENERATE(
                profile_name => 'GENAI_PROFILE',
                prompt       => p_request,
                action       => 'SHOWSQL'
            );
            DBMS_OUTPUT.PUT_LINE('Generated SQL: ' || l_sql);
            
            -- In a real agent, you would execute this safely and format the result
            -- EXECUTE IMMEDIATE l_sql ...
        ELSE
            -- 3. If it's a chat, get a direct response
            l_response := DBMS_CLOUD_AI.GENERATE(
                profile_name => 'GENAI_PROFILE',
                prompt       => p_request,
                action       => 'CHAT'
            );
            DBMS_OUTPUT.PUT_LINE('AI Response: ' || l_response);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error in AI Agent: ' || SQLERRM);
    END process_request;

END ai_agent_pkg;
/

-- Example Execution:
-- EXEC ai_agent_pkg.process_request('Tell me a joke about databases');
-- EXEC ai_agent_pkg.process_request('Show me all articles from 2026');
