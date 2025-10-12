-- ====================================================================
-- Example: User Management E2E Flow - Multi-Step Test
-- ====================================================================
-- This example demonstrates:
-- 1. Multi-step test flow (Register → Login → Get Profile → Update Profile)
-- 2. Inter-step variable passing using outputs
-- 3. Dynamic variable generation ({{$randomUser}}, {{$randomPassword}})
-- 4. Database validation (optional)
-- ====================================================================

BEGIN;

-- Step 1: Create the test case
WITH new_case AS (
    INSERT INTO api_auto_cases (
        name,
        description,
        service,
        module,
        component,
        tags,
        author,
        parameters
    ) VALUES (
        'User Registration and Profile Management E2E',
        'End-to-end test covering user registration, login, profile retrieval, and profile update',
        'user_svc',
        'User Management',
        'Authentication & Profile',
        ARRAY['p0', 'e2e', 'regression'],
        'test_team',
        '{
          "steps": [
            {
              "order": 1,
              "description": "Register a new user account",
              "path": "/api/users/register",
              "method": "POST",
              "request": {
                "params": null,
                "headers": {
                  "Content-Type": "application/json"
                },
                "body": {
                  "username": "{{$randomUser}}",
                  "password": "{{$randomPassword(16)}}",
                  "email": "{{$randomEmail}}",
                  "phone": "{{$randomPhone}}"
                }
              },
              "validations": {
                "expectedStatusCode": 201,
                "notNull": [
                  "$.code",
                  "$.data.user_id",
                  "$.data.username"
                ],
                "body": {
                  "code": 0,
                  "message": "User registered successfully"
                }
              },
              "outputs": [
                {
                  "variable_name": "user_id",
                  "source": "response_body",
                  "json_path": "data.user_id"
                },
                {
                  "variable_name": "username",
                  "source": "response_body",
                  "json_path": "data.username"
                }
              ]
            },
            {
              "order": 2,
              "description": "Login with the newly created user",
              "path": "/api/users/login",
              "method": "POST",
              "request": {
                "params": null,
                "headers": {
                  "Content-Type": "application/json"
                },
                "body": {
                  "username": "{{$randomUser}}",
                  "password": "{{$randomPassword(16)}}"
                }
              },
              "validations": {
                "expectedStatusCode": 200,
                "notNull": [
                  "$.code",
                  "$.data.token",
                  "$.data.user_id"
                ],
                "body": {
                  "code": 0,
                  "message": "Login successful",
                  "data": {
                    "user_id": "{{step_1.body.data.user_id}}"
                  }
                }
              },
              "outputs": [
                {
                  "variable_name": "auth_token",
                  "source": "response_body",
                  "json_path": "data.token"
                }
              ]
            },
            {
              "order": 3,
              "description": "Get user profile using the authentication token",
              "path": "/api/users/{{step_1.body.data.user_id}}/profile",
              "method": "GET",
              "request": {
                "params": null,
                "headers": {
                  "Content-Type": "application/json",
                  "Authorization": "Bearer {{step_2.body.data.token}}"
                },
                "body": null
              },
              "validations": {
                "expectedStatusCode": 200,
                "notNull": [
                  "$.code",
                  "$.data.user_id",
                  "$.data.username",
                  "$.data.email"
                ],
                "body": {
                  "code": 0,
                  "data": {
                    "user_id": "{{step_1.body.data.user_id}}",
                    "username": "{{$randomUser}}",
                    "email": "{{$randomEmail}}"
                  }
                }
              },
              "outputs": [
                {
                  "variable_name": "current_email",
                  "source": "response_body",
                  "json_path": "data.email"
                }
              ]
            },
            {
              "order": 4,
              "description": "Update user profile",
              "path": "/api/users/{{step_1.body.data.user_id}}/profile",
              "method": "PUT",
              "request": {
                "params": null,
                "headers": {
                  "Content-Type": "application/json",
                  "Authorization": "Bearer {{step_2.body.data.token}}"
                },
                "body": {
                  "email": "{{@new_email}}",
                  "phone": "{{@new_phone}}"
                }
              },
              "validations": {
                "expectedStatusCode": 200,
                "notNull": [
                  "$.code",
                  "$.data.user_id"
                ],
                "body": {
                  "code": 0,
                  "message": "Profile updated successfully",
                  "data": {
                    "user_id": "{{step_1.body.data.user_id}}",
                    "email": "{{@new_email}}",
                    "phone": "{{@new_phone}}"
                  }
                }
              },
              "outputs": []
            }
          ]
        }'::jsonb
    )
    RETURNING id
)

-- Step 2: Create all data sets
INSERT INTO case_data_sets (
    case_id,
    data_set_name,
    variables,
    validations_override,
    environments,
    jira_id,
    tags,
    is_active
)
SELECT
    id,
    data_set_name,
    variables::jsonb,
    validations_override::jsonb,
    environments,
    jira_id,
    tags,
    is_active
FROM new_case, (
    VALUES
        -- Positive Test Case: Complete E2E flow
        (
            'Complete user registration and profile update flow',
            '{
              "new_email": "updated_user@example.com",
              "new_phone": "+1-555-9999"
            }',
            null,
            ARRAY['uat'],
            'PROJ-1001',
            ARRAY['smoke', 'e2e', 'positive'],
            true
        ),
        -- Alternative Test Case: Different update values
        (
            'E2E flow with different profile values',
            '{
              "new_email": "different_email@test.com",
              "new_phone": "+1-555-8888"
            }',
            null,
            ARRAY['uat'],
            null::varchar,
            ARRAY['e2e', 'positive'],
            true
        )
) AS datasets(
    data_set_name,
    variables,
    validations_override,
    environments,
    jira_id,
    tags,
    is_active
);

-- Step 3: Verify creation
SELECT
    ac.id AS case_id,
    ac.name AS case_name,
    ac.service,
    COUNT(cds.id) AS dataset_count,
    STRING_AGG(cds.data_set_name, ', ' ORDER BY cds.id) AS datasets
FROM api_auto_cases ac
LEFT JOIN case_data_sets cds ON cds.case_id = ac.id
WHERE ac.name = 'User Registration and Profile Management E2E'
GROUP BY ac.id, ac.name, ac.service;

COMMIT;

-- ====================================================================
-- How to run this test
-- ====================================================================

-- 1. Get the case_id from the verification output above, or run:
-- SELECT id, name FROM api_auto_cases WHERE name = 'User Registration and Profile Management E2E';

-- 2. Execute the test:
-- python run.py --env uat --id <case_id>

-- 3. Execute with debug mode to see all step details:
-- python run.py --env uat --id <case_id> --debug-mode

-- 4. View the Allure report:
-- http://127.0.0.1:8889

-- ====================================================================
-- Variable Passing Flow Diagram
-- ====================================================================

-- Step 1: Register User
-- ├─ Generates: {{$randomUser}}, {{$randomPassword(16)}}, {{$randomEmail}}, {{$randomPhone}}
-- └─ Outputs: user_id, username
--
-- Step 2: Login
-- ├─ Uses: {{$randomUser}}, {{$randomPassword(16)}} (same values as Step 1)
-- ├─ Validates: user_id matches {{step_1.body.data.user_id}}
-- └─ Outputs: auth_token
--
-- Step 3: Get Profile
-- ├─ Uses: {{step_1.body.data.user_id}} in URL path
-- ├─ Uses: {{step_2.body.data.token}} in Authorization header
-- ├─ Validates: user_id, username, email match previous steps
-- └─ Outputs: current_email
--
-- Step 4: Update Profile
-- ├─ Uses: {{step_1.body.data.user_id}} in URL path
-- ├─ Uses: {{step_2.body.data.token}} in Authorization header
-- ├─ Uses: {{@new_email}}, {{@new_phone}} from data set variables
-- └─ Validates: Updated values match input

-- ====================================================================
-- Variable Types Used in This Example
-- ====================================================================

-- 1. Dynamic Variables (generated once per test, cached for all steps):
--    - {{$randomUser}}         → Generates random username (e.g., "user_abc123")
--    - {{$randomPassword(16)}} → Generates 16-character password
--    - {{$randomEmail}}        → Generates random email (e.g., "user_abc123@test.com")
--    - {{$randomPhone}}        → Generates random phone number

-- 2. Data Set Variables (from case_data_sets.variables):
--    - {{@new_email}}          → Updated email for profile update
--    - {{@new_phone}}          → Updated phone for profile update

-- 3. Inter-Step Variables (from previous step outputs):
--    - {{step_1.body.data.user_id}}  → User ID from registration response
--    - {{step_2.body.data.token}}    → Auth token from login response

-- ====================================================================
-- Advanced: Adding Database Validation
-- ====================================================================

-- You can optionally add database validation to Step 4 to verify the
-- profile update was persisted correctly:

-- Add this to Step 4's validations (requires app_db_connection_string
-- configured in test_environments table):

-- "dbValidation": {
--   "query": "SELECT email, phone FROM users WHERE user_id = '{{step_1.body.data.user_id}}'",
--   "expectedFromResponse": {
--     "email": "data.email",
--     "phone": "data.phone"
--   }
-- }

-- This will:
-- 1. Execute the SQL query against the application database
-- 2. Extract "email" and "phone" from the API response
-- 3. Compare database values with API response values
-- 4. Fail the test if they don't match

-- ====================================================================
-- Key Learning Points
-- ====================================================================

-- 1. Multi-Step Flow Design:
--    - Each step builds on the previous steps
--    - Use outputs to extract values for later steps
--    - Use inter-step variables to reference previous responses

-- 2. Dynamic Variables:
--    - Generated once at the start of test execution
--    - Same value used across all steps (crucial for login)
--    - Ensures unique test data on each run

-- 3. Data Set Variables:
--    - Parameterize values that differ between scenarios
--    - Enable testing same flow with different inputs
--    - Use for expected values in validations

-- 4. Authentication Flow:
--    - Step 1: Create user
--    - Step 2: Get token
--    - Step 3-4: Use token in Authorization header

-- 5. URL Path Variables:
--    - Can use placeholders in path: "/api/users/{{step_1.body.data.user_id}}/profile"
--    - Framework resolves before making request

-- 6. Validation with Previous Step Data:
--    - Can validate current response against previous responses
--    - Ensures data consistency across the flow
--    - Example: "user_id": "{{step_1.body.data.user_id}}"

-- ====================================================================
-- Extending This Example
-- ====================================================================

-- To add more steps to this flow:

-- 1. Delete User (cleanup):
--    - Path: "/api/users/{{step_1.body.data.user_id}}"
--    - Method: DELETE
--    - Authorization: Bearer {{step_2.body.data.token}}
--    - Validation: 200 status, user deleted message

-- 2. Verify Deletion:
--    - Path: "/api/users/{{step_1.body.data.user_id}}/profile"
--    - Method: GET
--    - Authorization: Bearer {{step_2.body.data.token}}
--    - Validation: 404 status, user not found error

-- 3. Add Negative Scenarios with validations_override:
--    - Invalid token → 401 Unauthorized
--    - Invalid email format → 400 Bad Request
--    - Duplicate username → 409 Conflict

-- ====================================================================
-- Troubleshooting
-- ====================================================================

-- Q: Why does login fail with "Invalid credentials"?
-- A: Ensure {{$randomUser}} and {{$randomPassword(16)}} use the SAME
--    placeholder text in both Step 1 and Step 2. The framework caches
--    dynamic variables by their exact placeholder name.

-- Q: How do I see the actual values of dynamic variables?
-- A: Use --debug-mode flag:
--    python run.py --env uat --id <case_id> --debug-mode
--    Then check auto_test_audit table for resolved values.

-- Q: Can I reference nested JSON in inter-step variables?
-- A: Yes! Use dot notation: {{step_1.body.data.nested.field.value}}

-- Q: What if I need to pass a value from Step 1 to Step 3, skipping Step 2?
-- A: No problem! You can reference any previous step from any later step:
--    {{step_1.body.data.user_id}} works in Step 3, 4, 5, etc.

-- ====================================================================
