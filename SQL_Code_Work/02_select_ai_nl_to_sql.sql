-- Oracle AI Database: Select AI (Natural Language to SQL)
-- This script shows how to configure and use Select AI to query data using natural language.

-- 1. Configure the AI Profile (Requires OCI Generative AI or OpenAI credentials)
/*
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'api.openai.com',
    ace  => xs$ace_type(privilege_list => xs$name_list('connect'),
                        principal_name => 'MY_USER',
                        principal_type => xs_acl.ptype_db)
  );
END;
/
*/

-- 2. Create an AI Profile
-- This profile tells the database which LLM to use and which tables to "see".
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
      profile_name => 'GENAI_PROFILE',
      attributes   => '{"provider": "openai", "model": "gpt-4"}',
      description  => 'Profile for Natural Language to SQL translation'
  );
END;
/

-- 3. Enable the profile for the session
EXEC DBMS_CLOUD_AI.SET_PROFILE('GENAI_PROFILE');

-- 4. Query using Natural Language
-- The 'SELECT AI' syntax intercepts the string and converts it to SQL.
SELECT AI what are the top 5 articles about database performance;

-- 5. See the generated SQL without executing
SELECT AI SHOWSQL what is the average length of article content;

-- 6. Conversational AI (Maintaining context)
SELECT AI CHAT how many articles were added today;
SELECT AI CHAT can you summarize them;
