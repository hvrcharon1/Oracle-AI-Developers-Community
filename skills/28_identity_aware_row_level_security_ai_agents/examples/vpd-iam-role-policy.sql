-- =============================================================================
-- Example VPD Policy: IAM Application Role-Based Row-Level Security
-- Purpose : Control row visibility using OCI IAM Application Roles surfaced
--           in CLIENTCONTEXT.IAM_DOMAIN_APP_ROLES.
-- Rules   : DB_ADMIN role    -> unrestricted (all rows)
--           DATA_ANALYST role -> EMEA region rows only
--           Default (no role) -> deny all (1=0)
-- Credit  : Inspired by Jeff Smith (@thatjeffsmith)
--           https://www.thatjeffsmith.com/archive/2026/05/who-is-using-your-oracle-data-ai-and-how-to-secure-it/
-- =============================================================================

-- Step 1: Create the policy function
CREATE OR REPLACE FUNCTION <SCHEMA>.sales_role_policy (
  p_schema IN VARCHAR2,
  p_object IN VARCHAR2
) RETURN VARCHAR2 AS
  v_roles VARCHAR2(4000) := SYS_CONTEXT('CLIENTCONTEXT', 'IAM_DOMAIN_APP_ROLES');
BEGIN
  -- Full access for administrators
  IF INSTR(v_roles, 'DB_ADMIN') > 0 THEN
    RETURN NULL;
  END IF;

  -- Regional access for analysts
  IF INSTR(v_roles, 'DATA_ANALYST') > 0 THEN
    RETURN 'region = ''EMEA''';
  END IF;

  -- Default-deny: no recognised role or absent context
  -- Returning '1=0' causes every query to return zero rows without an error.
  RETURN '1=0';
END sales_role_policy;
/

-- Step 2: Attach the policy
BEGIN
  DBMS_RLS.ADD_POLICY(
    object_schema   => '<SCHEMA>',
    object_name     => 'SALES',
    policy_name     => 'SALES_ROLE_VISIBILITY',
    function_schema => '<SCHEMA>',
    policy_function => 'SALES_ROLE_POLICY',
    statement_types => 'SELECT, UPDATE, DELETE',
    update_check    => TRUE,
    policy_type     => DBMS_RLS.DYNAMIC,
    enable          => TRUE
  );
END;
/

-- Step 3: Check active policies on the table
SELECT policy_name, policy_function, enable, sel, upd, del
FROM   dba_policies
WHERE  object_name  = 'SALES'
  AND  object_owner = UPPER('<SCHEMA>');
