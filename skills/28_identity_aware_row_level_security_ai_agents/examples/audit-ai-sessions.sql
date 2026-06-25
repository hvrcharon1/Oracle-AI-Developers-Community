-- =============================================================================
-- Targeted Unified Audit Policy for AI / MCP Agent Sessions
-- Purpose : Log SELECT access on a sensitive table ONLY when the session
--           originates from an AI/MCP client (OAUTH_CLIENT_NAME is non-null).
--           Avoids auditing every direct DB connection while capturing every
--           AI-mediated access path.
-- Requires: AUDIT ADMIN privilege
-- Credit  : Inspired by Jeff Smith (@thatjeffsmith)
--           https://www.thatjeffsmith.com/archive/2026/05/who-is-using-your-oracle-data-ai-and-how-to-secure-it/
-- =============================================================================

-- Step 1: Create the audit policy scoped to AI-originated sessions
CREATE AUDIT POLICY ai_sensitive_access
  ACTIONS SELECT ON <SCHEMA>.<TABLE_NAME>
  WHEN q'[SYS_CONTEXT('CLIENTCONTEXT','OAUTH_CLIENT_NAME') IS NOT NULL]'
  EVALUATE PER SESSION;

-- Step 2: Enable the policy
AUDIT POLICY ai_sensitive_access;

-- Step 3: Verify the policy exists
SELECT policy_name, enabled_option, entity_name, entity_type
FROM   audit_unified_enabled_policies
WHERE  policy_name = 'AI_SENSITIVE_ACCESS';

-- Step 4: Query recent AI agent access in the unified audit trail
SELECT
  event_timestamp,
  dbusername,
  unified_audit_policies,
  action_name,
  object_schema,
  object_name,
  sql_text
FROM   unified_audit_trail
WHERE  unified_audit_policies LIKE '%AI_SENSITIVE_ACCESS%'
ORDER BY event_timestamp DESC
FETCH FIRST 50 ROWS ONLY;

-- To disable the policy:
-- NOAUDIT POLICY ai_sensitive_access;

-- To drop the policy entirely:
-- DROP AUDIT POLICY ai_sensitive_access;
