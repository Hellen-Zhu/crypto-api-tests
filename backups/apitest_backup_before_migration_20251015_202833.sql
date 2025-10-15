--
-- PostgreSQL database dump
--

-- Dumped from database version 13.22 (Debian 13.22-1.pgdg13+1)
-- Dumped by pg_dump version 15.13 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.case_data_sets_old DROP CONSTRAINT IF EXISTS case_data_sets_case_id_fkey;
ALTER TABLE IF EXISTS ONLY public.auto_test_audit DROP CONSTRAINT IF EXISTS auto_test_audit_audit_case_id_fkey;
DROP TRIGGER IF EXISTS trigger_update_api_auto_cases_updated_at ON public.api_auto_cases;
DROP INDEX IF EXISTS public.ix_case_data_sets_environments;
DROP INDEX IF EXISTS public.ix_auto_case_audit_runid;
DROP INDEX IF EXISTS public.ix_api_auto_cases_tags;
DROP INDEX IF EXISTS public.ix_api_auto_cases_service;
DROP INDEX IF EXISTS public.ix_api_auto_cases_module;
DROP INDEX IF EXISTS public.ix_api_auto_cases_component;
DROP INDEX IF EXISTS public.idx_cases_tags;
DROP INDEX IF EXISTS public.idx_cases_service;
DROP INDEX IF EXISTS public.idx_cases_module;
DROP INDEX IF EXISTS public.idx_cases_jira;
DROP INDEX IF EXISTS public.idx_cases_environments;
DROP INDEX IF EXISTS public.idx_cases_component;
DROP INDEX IF EXISTS public.idx_api_auto_cases_parameters;
ALTER TABLE IF EXISTS ONLY public.api_auto_cases DROP CONSTRAINT IF EXISTS unique_jira_id;
ALTER TABLE IF EXISTS ONLY public.test_environments DROP CONSTRAINT IF EXISTS test_environments_pkey;
ALTER TABLE IF EXISTS ONLY public.test_environments DROP CONSTRAINT IF EXISTS test_environments_name_service_key;
ALTER TABLE IF EXISTS ONLY public.case_data_sets_old DROP CONSTRAINT IF EXISTS case_data_sets_pkey;
ALTER TABLE IF EXISTS ONLY public.case_data_sets_old DROP CONSTRAINT IF EXISTS case_data_sets_jira_id_key;
ALTER TABLE IF EXISTS ONLY public.auto_test_audit DROP CONSTRAINT IF EXISTS auto_test_audit_pkey;
ALTER TABLE IF EXISTS ONLY public.auto_progress DROP CONSTRAINT IF EXISTS auto_progress_pkey;
ALTER TABLE IF EXISTS ONLY public.auto_case_audit DROP CONSTRAINT IF EXISTS auto_case_audit_pkey;
ALTER TABLE IF EXISTS ONLY public.api_auto_cases_old DROP CONSTRAINT IF EXISTS api_auto_cases_pkey;
ALTER TABLE IF EXISTS ONLY public.api_auto_cases DROP CONSTRAINT IF EXISTS api_auto_cases_new_pkey;
ALTER TABLE IF EXISTS public.test_environments ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.case_data_sets_old ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.auto_test_audit ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.auto_progress ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.auto_case_audit ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.api_auto_cases_old ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.api_auto_cases ALTER COLUMN id DROP DEFAULT;
DROP VIEW IF EXISTS public.v_migration_status;
DROP TABLE IF EXISTS public.test_environments_old_20251013;
DROP SEQUENCE IF EXISTS public.test_environments_id_seq;
DROP TABLE IF EXISTS public.test_environments;
DROP SEQUENCE IF EXISTS public.case_data_sets_id_seq;
DROP TABLE IF EXISTS public.case_data_sets_old;
DROP TABLE IF EXISTS public.case_data_sets_backup;
DROP SEQUENCE IF EXISTS public.auto_test_audit_id_seq;
DROP TABLE IF EXISTS public.auto_test_audit;
DROP SEQUENCE IF EXISTS public.auto_progress_id_seq;
DROP TABLE IF EXISTS public.auto_progress;
DROP SEQUENCE IF EXISTS public.auto_case_audit_id_seq;
DROP TABLE IF EXISTS public.auto_case_audit;
DROP SEQUENCE IF EXISTS public.api_auto_cases_new_id_seq;
DROP SEQUENCE IF EXISTS public.api_auto_cases_id_seq;
DROP TABLE IF EXISTS public.api_auto_cases_old;
DROP TABLE IF EXISTS public.api_auto_cases_backup;
DROP TABLE IF EXISTS public.api_auto_cases;
DROP FUNCTION IF EXISTS public.validate_parameters_structure();
DROP FUNCTION IF EXISTS public.update_updated_at_column();
DROP FUNCTION IF EXISTS public.rollback_migration(target_case_id integer);
DROP FUNCTION IF EXISTS public.preview_migration(target_case_id integer);
DROP FUNCTION IF EXISTS public.migrate_case_to_parameters(target_case_id integer);
DROP FUNCTION IF EXISTS public.migrate_all_cases_to_parameters();
DROP FUNCTION IF EXISTS public.get_service_base_url(env_name character varying, svc_name character varying);
-- *not* dropping schema, since initdb creates it
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: get_service_base_url(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_service_base_url(env_name character varying, svc_name character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    url VARCHAR;
BEGIN
    SELECT base_url INTO url
    FROM test_environments
    WHERE name = env_name AND service = svc_name AND is_active = true;

    RETURN url;
END;
$$;


ALTER FUNCTION public.get_service_base_url(env_name character varying, svc_name character varying) OWNER TO postgres;

--
-- Name: migrate_all_cases_to_parameters(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.migrate_all_cases_to_parameters() RETURNS TABLE(case_id integer, case_name text, step_count integer, migrated boolean, error_message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    case_record RECORD;
    steps_json JSONB;
    steps_count INTEGER;
BEGIN
    FOR case_record IN
        SELECT id, name FROM api_auto_cases WHERE parameters IS NULL
    LOOP
        BEGIN
            -- Migrate this case
            steps_json := migrate_case_to_parameters(case_record.id);

            IF steps_json IS NULL THEN
                -- No steps found
                case_id := case_record.id;
                case_name := case_record.name;
                step_count := 0;
                migrated := FALSE;
                error_message := 'No steps found in api_actions';
                RETURN NEXT;
            ELSE
                -- Success
                steps_count := jsonb_array_length(steps_json->'steps');
                case_id := case_record.id;
                case_name := case_record.name;
                step_count := steps_count;
                migrated := TRUE;
                error_message := NULL;
                RETURN NEXT;

                RAISE NOTICE 'Migrated case % (%) with % steps',
                    case_record.id, case_record.name, steps_count;
            END IF;

        EXCEPTION WHEN OTHERS THEN
            -- Catch migration errors
            case_id := case_record.id;
            case_name := case_record.name;
            step_count := 0;
            migrated := FALSE;
            error_message := SQLERRM;
            RETURN NEXT;

            RAISE WARNING 'Failed to migrate case %: %', case_record.id, SQLERRM;
        END;
    END LOOP;
END;
$$;


ALTER FUNCTION public.migrate_all_cases_to_parameters() OWNER TO postgres;

--
-- Name: migrate_case_to_parameters(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.migrate_case_to_parameters(target_case_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    parameters_json JSONB;
    step_count INTEGER;
BEGIN
    -- Build parameters structure from api_actions + shared_actions
    -- When shared_action_ref exists, use shared_action's fields
    -- Otherwise use api_action's own fields
    SELECT jsonb_build_object(
        'steps', jsonb_agg(
            jsonb_build_object(
                'order', a.step_order,
                'description', COALESCE(a.description, sa.description, ''),
                'method', UPPER(COALESCE(sa.http_method, a.http_method)),
                'path', COALESCE(sa.api_url_path, a.api_url_path),
                'request', jsonb_build_object(
                    'headers', COALESCE(sa.headers, a.headers, '{}'::jsonb),
                    'params', COALESCE(sa.params, a.params, '{}'::jsonb),
                    'body', COALESCE(sa.body, a.body, '{}'::jsonb)
                ),
                'validations', COALESCE(
                    sa.validations,
                    a.validations,
                    '{"expectedStatusCode": 200}'::jsonb
                ),
                'outputs', COALESCE(sa.outputs, a.outputs, '[]'::jsonb)
            ) ORDER BY a.step_order
        )
    ) INTO parameters_json
    FROM api_actions a
    LEFT JOIN shared_actions sa ON a.shared_action_ref = sa.name
    WHERE a.case_id = target_case_id;

    -- Check if we got any steps
    GET DIAGNOSTICS step_count = ROW_COUNT;

    IF step_count = 0 THEN
        RAISE NOTICE 'Case % has no steps in api_actions table', target_case_id;
        RETURN NULL;
    END IF;

    -- Update the case
    UPDATE api_auto_cases
    SET parameters = parameters_json
    WHERE id = target_case_id;

    RETURN parameters_json;
END;
$$;


ALTER FUNCTION public.migrate_case_to_parameters(target_case_id integer) OWNER TO postgres;

--
-- Name: FUNCTION migrate_case_to_parameters(target_case_id integer); Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON FUNCTION public.migrate_case_to_parameters(target_case_id integer) IS 'Migrates a single test case from api_actions to api_auto_cases.parameters.
Properly resolves shared_action_ref by joining with shared_actions table.
Returns the migrated parameters JSONB or NULL if no steps found.';


--
-- Name: preview_migration(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.preview_migration(target_case_id integer) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
DECLARE
    preview_json JSONB;
BEGIN
    SELECT jsonb_build_object(
        'case_id', target_case_id,
        'case_name', c.name,
        'current_status', CASE WHEN c.parameters IS NULL THEN 'Not migrated' ELSE 'Already migrated' END,
        'steps', jsonb_agg(
            jsonb_build_object(
                'order', a.step_order,
                'description', a.description,
                'method', a.http_method,
                'path', a.api_url_path,
                'has_validations', a.validations IS NOT NULL,
                'shared_action_ref', a.shared_action_ref
            ) ORDER BY a.step_order
        )
    ) INTO preview_json
    FROM api_auto_cases c
    LEFT JOIN api_actions a ON a.case_id = c.id
    WHERE c.id = target_case_id
    GROUP BY c.id, c.name, c.parameters;

    RETURN preview_json;
END;
$$;


ALTER FUNCTION public.preview_migration(target_case_id integer) OWNER TO postgres;

--
-- Name: rollback_migration(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.rollback_migration(target_case_id integer DEFAULT NULL::integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF target_case_id IS NOT NULL THEN
        -- Rollback single case
        UPDATE api_auto_cases
        SET parameters = NULL
        WHERE id = target_case_id;

        RAISE NOTICE 'Rolled back case %', target_case_id;
    ELSE
        -- Rollback all cases
        UPDATE api_auto_cases
        SET parameters = NULL
        WHERE parameters IS NOT NULL;

        RAISE NOTICE 'Rolled back all cases';
    END IF;
END;
$$;


ALTER FUNCTION public.rollback_migration(target_case_id integer) OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

--
-- Name: validate_parameters_structure(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_parameters_structure() RETURNS TABLE(case_id integer, case_name text, issue text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.name,
        'Missing steps array' as issue
    FROM api_auto_cases c
    WHERE c.parameters IS NOT NULL
      AND NOT (c.parameters ? 'steps');

    RETURN QUERY
    SELECT
        c.id,
        c.name,
        'Empty steps array' as issue
    FROM api_auto_cases c
    WHERE c.parameters IS NOT NULL
      AND jsonb_array_length(c.parameters->'steps') = 0;

    RETURN QUERY
    SELECT
        c.id,
        c.name,
        'Step ' || (step_idx + 1) || ' missing required field: ' || missing_field as issue
    FROM api_auto_cases c,
         LATERAL jsonb_array_elements(c.parameters->'steps') WITH ORDINALITY AS step_elem(step, step_idx),
         LATERAL (
             SELECT unnest(ARRAY['order', 'method', 'path', 'request']) as missing_field
             WHERE NOT (step_elem.step ? unnest(ARRAY['order', 'method', 'path', 'request']))
         ) missing
    WHERE c.parameters IS NOT NULL;
END;
$$;


ALTER FUNCTION public.validate_parameters_structure() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: api_auto_cases; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.api_auto_cases (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    service character varying(100) NOT NULL,
    module character varying(100),
    component character varying(100),
    tags text[],
    environments text[],
    jira_id character varying(50),
    author character varying(50),
    test_config jsonb NOT NULL,
    enable boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.api_auto_cases OWNER TO postgres;

--
-- Name: api_auto_cases_backup; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.api_auto_cases_backup (
    id integer,
    name character varying(255),
    description text,
    service character varying(100),
    module character varying(100),
    component character varying(100),
    tags text[],
    author character varying(50),
    created_at timestamp with time zone,
    parameters jsonb
);


ALTER TABLE public.api_auto_cases_backup OWNER TO postgres;

--
-- Name: api_auto_cases_old; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.api_auto_cases_old (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    service character varying(100) NOT NULL,
    module character varying(100),
    component character varying(100),
    tags text[],
    author character varying(50),
    created_at timestamp with time zone DEFAULT now(),
    parameters jsonb,
    CONSTRAINT parameters_structure_check CHECK (((parameters IS NULL) OR ((parameters ? 'steps'::text) AND (jsonb_typeof((parameters -> 'steps'::text)) = 'array'::text) AND (jsonb_array_length((parameters -> 'steps'::text)) > 0))))
);


ALTER TABLE public.api_auto_cases_old OWNER TO postgres;

--
-- Name: COLUMN api_auto_cases_old.parameters; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON COLUMN public.api_auto_cases_old.parameters IS 'Complete test step definitions as JSONB.
Structure: {
  "steps": [
    {
      "order": 1,
      "description": "Step description",
      "method": "POST",
      "path": "/api/endpoint",
      "request": {
        "headers": {...},
        "params": {...},
        "body": {...}
      },
      "validations": {
        "expectedStatusCode": 200,
        "notNull": ["$.field"]
      },
      "outputs": [
        {
          "variable_name": "var_name",
          "source": "body",
          "json_path": "$.field"
        }
      ]
    }
  ]
}';


--
-- Name: api_auto_cases_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.api_auto_cases_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.api_auto_cases_id_seq OWNER TO postgres;

--
-- Name: api_auto_cases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.api_auto_cases_id_seq OWNED BY public.api_auto_cases_old.id;


--
-- Name: api_auto_cases_new_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.api_auto_cases_new_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.api_auto_cases_new_id_seq OWNER TO postgres;

--
-- Name: api_auto_cases_new_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.api_auto_cases_new_id_seq OWNED BY public.api_auto_cases.id;


--
-- Name: auto_case_audit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auto_case_audit (
    id integer NOT NULL,
    runid character varying(50) NOT NULL,
    case_id integer,
    data_set_id integer,
    scenario text,
    issue_key character varying(50),
    run_status character varying(20),
    duration real,
    error_message text,
    variables jsonb,
    update_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.auto_case_audit OWNER TO postgres;

--
-- Name: auto_case_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.auto_case_audit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auto_case_audit_id_seq OWNER TO postgres;

--
-- Name: auto_case_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.auto_case_audit_id_seq OWNED BY public.auto_case_audit.id;


--
-- Name: auto_progress; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auto_progress (
    id integer NOT NULL,
    runid character varying(50),
    version_id character varying(35),
    component character varying(50),
    total_cases integer,
    passes integer,
    failures integer,
    skips integer,
    begin_time timestamp without time zone,
    end_time timestamp without time zone,
    releaseversion character varying(200),
    task_status character varying(25),
    run_by character varying(50),
    label character varying(1000),
    runmode character varying(255),
    profile character varying(200),
    update_time timestamp without time zone
);


ALTER TABLE public.auto_progress OWNER TO postgres;

--
-- Name: auto_progress_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.auto_progress_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auto_progress_id_seq OWNER TO postgres;

--
-- Name: auto_progress_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.auto_progress_id_seq OWNED BY public.auto_progress.id;


--
-- Name: auto_test_audit; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.auto_test_audit (
    id integer NOT NULL,
    audit_case_id integer NOT NULL,
    step_order integer,
    action_description text,
    request_details jsonb,
    response_details jsonb,
    step_status character varying(20)
);


ALTER TABLE public.auto_test_audit OWNER TO postgres;

--
-- Name: auto_test_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.auto_test_audit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.auto_test_audit_id_seq OWNER TO postgres;

--
-- Name: auto_test_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.auto_test_audit_id_seq OWNED BY public.auto_test_audit.id;


--
-- Name: case_data_sets_backup; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.case_data_sets_backup (
    id integer,
    case_id integer,
    data_set_name character varying(255),
    variables jsonb,
    validations_override jsonb,
    environments text[],
    jira_id character varying(50),
    tags text[],
    is_active boolean
);


ALTER TABLE public.case_data_sets_backup OWNER TO postgres;

--
-- Name: case_data_sets_old; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.case_data_sets_old (
    id integer NOT NULL,
    case_id integer NOT NULL,
    data_set_name character varying(255) NOT NULL,
    variables jsonb NOT NULL,
    validations_override jsonb,
    environments text[],
    jira_id character varying(50),
    tags text[],
    is_active boolean
);


ALTER TABLE public.case_data_sets_old OWNER TO postgres;

--
-- Name: case_data_sets_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.case_data_sets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.case_data_sets_id_seq OWNER TO postgres;

--
-- Name: case_data_sets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.case_data_sets_id_seq OWNED BY public.case_data_sets_old.id;


--
-- Name: test_environments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test_environments (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    service character varying(50) NOT NULL,
    base_url character varying(255) NOT NULL,
    description text,
    is_active boolean DEFAULT true
);


ALTER TABLE public.test_environments OWNER TO postgres;

--
-- Name: test_environments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.test_environments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.test_environments_id_seq OWNER TO postgres;

--
-- Name: test_environments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.test_environments_id_seq OWNED BY public.test_environments.id;


--
-- Name: test_environments_old_20251013; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.test_environments_old_20251013 (
    id integer,
    name character varying(50),
    base_url character varying(255),
    app_db_connection_string text,
    description text,
    is_active boolean,
    services jsonb,
    service character varying(50)
);


ALTER TABLE public.test_environments_old_20251013 OWNER TO postgres;

--
-- Name: v_migration_status; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_migration_status AS
 SELECT count(*) AS total_cases,
    count(*) FILTER (WHERE (api_auto_cases_old.parameters IS NOT NULL)) AS migrated_cases,
    count(*) FILTER (WHERE (api_auto_cases_old.parameters IS NULL)) AS pending_cases,
    round((((count(*) FILTER (WHERE (api_auto_cases_old.parameters IS NOT NULL)))::numeric * 100.0) / (NULLIF(count(*), 0))::numeric), 2) AS migration_percentage
   FROM public.api_auto_cases_old;


ALTER TABLE public.v_migration_status OWNER TO postgres;

--
-- Name: VIEW v_migration_status; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.v_migration_status IS 'Shows overall migration progress from api_actions to parameters column';


--
-- Name: api_auto_cases id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_auto_cases ALTER COLUMN id SET DEFAULT nextval('public.api_auto_cases_new_id_seq'::regclass);


--
-- Name: api_auto_cases_old id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_auto_cases_old ALTER COLUMN id SET DEFAULT nextval('public.api_auto_cases_id_seq'::regclass);


--
-- Name: auto_case_audit id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auto_case_audit ALTER COLUMN id SET DEFAULT nextval('public.auto_case_audit_id_seq'::regclass);


--
-- Name: auto_progress id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auto_progress ALTER COLUMN id SET DEFAULT nextval('public.auto_progress_id_seq'::regclass);


--
-- Name: auto_test_audit id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auto_test_audit ALTER COLUMN id SET DEFAULT nextval('public.auto_test_audit_id_seq'::regclass);


--
-- Name: case_data_sets_old id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.case_data_sets_old ALTER COLUMN id SET DEFAULT nextval('public.case_data_sets_id_seq'::regclass);


--
-- Name: test_environments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_environments ALTER COLUMN id SET DEFAULT nextval('public.test_environments_id_seq'::regclass);


--
-- Data for Name: api_auto_cases; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.api_auto_cases (id, name, description, service, module, component, tags, environments, jira_id, author, test_config, enable, created_at, updated_at) FROM stdin;
1	WS_OrderBook_Depth50_Delta_Positive	Subscribe to orderbook with depth=50 in Delta mode (default recommended), verify initial snapshot and incremental updates	websocket_svc	market_data	orderbook	{P0,positive,delta,smoke}	{uat,production}	TC_001	Hellen	{"steps": [{"action": "connect", "request": {"url": "${websocket_url}"}, "protocol": "websocket", "step_name": "step_1_connect", "step_order": 1, "description": "Connect to WebSocket server"}, {"action": "send", "request": {"body": {"id": 1, "method": "subscribe", "params": {"channels": ["book.BTCUSD-PERP.50"]}}}, "protocol": "websocket", "step_name": "step_2_subscribe", "step_order": 2, "description": "Send subscription message - Delta mode with depth=50"}, {"action": "wait", "request": {"count": 1, "timeout": 10}, "protocol": "websocket", "step_name": "step_3_wait_snapshot", "step_order": 3, "description": "Wait for initial snapshot message", "validations": {"depth": 50, "channel": "book", "data.asks": {"type": "array"}, "data.bids": {"type": "array"}, "subscription": "book.BTCUSD-PERP.50", "instrument_name": "BTCUSD-PERP"}}, {"action": "wait", "request": {"count": 3, "timeout": 5}, "protocol": "websocket", "step_name": "step_4_wait_updates", "step_order": 4, "description": "Wait for incremental update messages", "validations": {"data": {"type": "object"}, "channel": "book"}}, {"action": "disconnect", "protocol": "websocket", "step_name": "step_5_disconnect", "step_order": 5, "description": "Disconnect WebSocket connection"}]}	t	2025-10-15 04:17:35.786924	2025-10-15 04:17:35.786924+00
2	WS_OrderBook_Depth50_Snapshot_Positive	Subscribe to orderbook with depth=50 in Snapshot mode, verify complete snapshot streaming	websocket_svc	market_data	orderbook	{P1,positive,snapshot}	{uat}	TC_003	Hellen	{"steps": [{"action": "connect", "request": {"url": "${websocket_url}"}, "protocol": "websocket", "step_name": "step_1_connect", "step_order": 1, "description": "Connect to WebSocket"}, {"action": "send", "request": {"body": {"id": 1, "method": "subscribe", "params": {"channels": ["book.BTCUSD-PERP.50"], "book_subscription_type": "SNAPSHOT"}}}, "protocol": "websocket", "step_name": "step_2_subscribe_snapshot", "step_order": 2, "description": "Subscribe in Snapshot mode"}, {"action": "wait", "request": {"count": 2, "timeout": 10}, "protocol": "websocket", "step_name": "step_3_verify_snapshot", "step_order": 3, "description": "Verify Snapshot messages", "validations": {"depth": 50, "channel": "book", "data.asks.length": {">=": 1}, "data.bids.length": {">=": 1}}}, {"action": "disconnect", "protocol": "websocket", "step_name": "step_4_disconnect", "step_order": 4, "description": "Disconnect"}]}	t	2025-10-15 04:17:35.786924	2025-10-15 04:17:35.786924+00
3	WS_OrderBook_BTCUSD_Instrument_Positive	Verify BTCUSD-PERP trading pair orderbook subscription	websocket_svc	market_data	orderbook	{P0,positive,instrument}	{uat,production}	TC_005	Hellen	{"steps": [{"action": "connect", "request": {"url": "${websocket_url}"}, "protocol": "websocket", "step_name": "step_1_connect", "step_order": 1, "description": "Connect to WebSocket"}, {"action": "send", "request": {"body": {"method": "subscribe", "params": {"channels": ["book.BTCUSD-PERP.10"]}}}, "protocol": "websocket", "step_name": "step_2_subscribe_btcusd", "step_order": 2, "description": "Subscribe to BTCUSD-PERP"}, {"action": "wait", "request": {"count": 1, "timeout": 10}, "protocol": "websocket", "step_name": "step_3_verify_instrument", "step_order": 3, "description": "Verify instrument_name field", "validations": {"subscription": "book.BTCUSD-PERP.10", "instrument_name": "BTCUSD-PERP"}}, {"action": "disconnect", "protocol": "websocket", "step_name": "step_4_disconnect", "step_order": 4, "description": "Disconnect"}]}	t	2025-10-15 04:17:35.786924	2025-10-15 04:17:35.786924+00
4	WS_OrderBook_InvalidSymbol_Negative	Use invalid instrument_name, verify error handling	websocket_svc	market_data	orderbook	{P0,negative,validation}	{uat}	TC_016	Hellen	{"steps": [{"action": "connect", "request": {"url": "${websocket_url}"}, "protocol": "websocket", "step_name": "step_1_connect", "step_order": 1, "description": "Connect to WebSocket"}, {"action": "send", "request": {"body": {"method": "subscribe", "params": {"channels": ["book.INVALID_SYMBOL.10"]}}}, "protocol": "websocket", "step_name": "step_2_subscribe_invalid", "step_order": 2, "description": "Send subscription with invalid symbol"}, {"action": "wait", "request": {"count": 1, "timeout": 5}, "protocol": "websocket", "step_name": "step_3_verify_error", "step_order": 3, "description": "Verify error response (or no data streaming)", "validations": {"code": {"!=": 0}}}, {"action": "disconnect", "protocol": "websocket", "step_name": "step_4_disconnect", "step_order": 4, "description": "Disconnect"}]}	t	2025-10-15 04:17:35.786924	2025-10-15 04:17:35.786924+00
5	WS_OrderBook_Depth10_Boundary	Use depth minimum valid value 10, verify boundary handling	websocket_svc	market_data	orderbook	{P0,boundary,depth}	{uat}	TC_028	Hellen	{"steps": [{"action": "connect", "request": {"url": "${websocket_url}"}, "protocol": "websocket", "step_name": "step_1_connect", "step_order": 1, "description": "Connect to WebSocket"}, {"action": "send", "request": {"body": {"method": "subscribe", "params": {"channels": ["book.BTCUSD-PERP.10"]}}}, "protocol": "websocket", "step_name": "step_2_subscribe_depth10", "step_order": 2, "description": "Subscribe with depth=10 (minimum value)"}, {"action": "wait", "request": {"count": 1, "timeout": 10}, "protocol": "websocket", "step_name": "step_3_verify_depth", "step_order": 3, "description": "Verify depth=10", "validations": {"depth": 10, "data.asks.length": {"<=": 10}, "data.bids.length": {"<=": 10}}}, {"action": "disconnect", "protocol": "websocket", "step_name": "step_4_disconnect", "step_order": 4, "description": "Disconnect"}]}	t	2025-10-15 04:17:35.786924	2025-10-15 04:17:35.786924+00
10	REST_Candlestick_MissingParam_Negative	Missing required parameter instrument_name, verify parameter validation	exchange_svc	market_data	candlestick	{P0,negative,validation}	{uat}	TC_R019	Hellen	{"steps": [{"path": "/public/get-candlestick", "method": "GET", "params": {}, "protocol": "http", "step_name": "step_1_missing_instrument", "step_order": 1, "description": "Do not pass instrument_name parameter", "validations": {"code": 40003, "message": "Invalid request"}, "expectedStatusCode": 400}]}	t	2025-10-15 04:17:35.786924	2025-10-15 09:02:43.928866+00
11	REST_Candlestick_Count1_Boundary	Use count minimum value 1, verify boundary handling	exchange_svc	market_data	candlestick	{P0,boundary,count}	{uat}	TC_R031	Hellen	{"steps": [{"path": "/public/get-candlestick", "method": "GET", "params": {"count": 1, "instrument_name": "BTCUSD-PERP"}, "protocol": "http", "step_name": "step_1_count_1", "step_order": 1, "description": "Query candlestick with count=1", "validations": {"body": {"id": -1, "code": 0, "method": "public/get-candlestick", "result": {"instrument_name": "BTCUSD-PERP"}}, "expectedStatusCode": 200, "body.result.data.length": 1}}]}	t	2025-10-15 04:17:35.786924	2025-10-15 07:32:45.609224+00
7	REST_Candlestick_MinimalParams_Positive	Query candlestick data with only required parameters, verify default behavior	exchange_svc	market_data	candlestick	{P0,positive,smoke}	{uat,production}	TC_R001	Hellen	{"steps": [{"path": "/public/get-candlestick", "method": "GET", "params": {"instrument_name": "BTCUSD-PERP"}, "protocol": "http", "step_name": "step_1_get_candlestick", "step_order": 1, "description": "Query candlestick data (only required parameters)", "validations": {"body": {"id": -1, "code": 0, "method": "public/get-candlestick", "result": {"instrument_name": "BTCUSD-PERP"}}, "body.result.data": {"type": "array"}, "expectedStatusCode": 200, "body.result.data.length": {">=": 1}}}]}	t	2025-10-15 04:17:35.786924	2025-10-15 07:32:45.609224+00
9	REST_Candlestick_TimeRange_Positive	Query candlestick data with start_ts and end_ts for specified time range	exchange_svc	market_data	candlestick	{P0,positive,timerange}	{uat}	TC_R011	Hellen	{"steps": [{"path": "/public/get-candlestick", "method": "GET", "params": {"count": 24, "end_ts": "${fn:timestamp()}", "start_ts": "${fn:timestamp_days_ago(1)}", "timeframe": "1h", "instrument_name": "BTCUSD-PERP"}, "protocol": "http", "step_name": "step_1_calculate_timestamps", "step_order": 1, "description": "Calculate time range (24 hours ago to now)", "validations": {"body": {"id": -1, "code": 0, "method": "public/get-candlestick", "result": {"instrument_name": "BTCUSD-PERP"}}, "body.result.data": {"type": "array"}, "expectedStatusCode": 200, "body.result.data.length": {"<=": 24, ">=": 1}}}]}	t	2025-10-15 04:17:35.786924	2025-10-15 07:32:45.609224+00
8	REST_Candlestick_Timeframe1h_Positive	Query 1-hour candlestick data, verify timeframe parameter	exchange_svc	market_data	candlestick	{P0,positive,timeframe}	{uat,production}	TC_R005	Hellen	{"steps": [{"path": "/public/get-candlestick", "method": "GET", "params": {"timeframe": "1h", "instrument_name": "BTCUSD-PERP"}, "protocol": "http", "step_name": "step_1_get_1h_candlestick", "step_order": 1, "description": "Query 1-hour candlestick", "validations": {"body": {"id": -1, "code": 0, "method": "public/get-candlestick", "result": {"instrument_name": "BTCUSD-PERP"}}, "body.result.data": {"type": "array"}, "expectedStatusCode": 200}}]}	t	2025-10-15 04:17:35.786924	2025-10-15 07:32:45.609224+00
12	REST_Candlestick_DataConsistency_Exception	Verify candlestick data consistency (h>=l, o/c within h and l range)	exchange_svc	market_data	candlestick	{P0,exception,data_quality}	{uat,production}	TC_R045	Hellen	{"steps": [{"path": "/public/get-candlestick", "method": "GET", "params": {"count": 10, "timeframe": "1h", "instrument_name": "BTCUSD-PERP"}, "protocol": "http", "step_name": "step_1_get_candlestick", "step_order": 1, "description": "Get candlestick data", "validations": {"body": {"id": -1, "code": 0, "method": "public/get-candlestick", "result": {"instrument_name": "BTCUSD-PERP"}}, "body.result.data": {"type": "array"}, "expectedStatusCode": 200}, "extract_vars": {"candlestick_data": "body.result.data"}}, {"path": "/public/get-candlestick", "method": "GET", "params": {"count": 5, "instrument_name": "BTCUSD-PERP"}, "protocol": "http", "step_name": "step_2_validate_data_consistency", "step_order": 2, "description": "Verify data consistency for each candlestick", "validations": {"customValidations": [{"type": "ohlc_logic"}], "expectedStatusCode": 200}}]}	t	2025-10-15 04:17:35.786924	2025-10-15 08:02:15.955691+00
\.


--
-- Data for Name: api_auto_cases_backup; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.api_auto_cases_backup (id, name, description, service, module, component, tags, author, created_at, parameters) FROM stdin;
11	Get Candlestick - Negative Tests	Negative test cases for candlestick data API - invalid parameters and error handling	exchange_svc	Reference and Market Data	Candlestick API	{p1,negative,market_data,candlestick}	hellen	2025-10-12 10:37:25.23485+00	{"steps": [{"path": "/exchange/v1/public/get-candlestick", "order": 1, "method": "GET", "request": {"body": null, "params": {"count": "{{@count}}", "timeframe": "{{@timeframe}}", "instrument_name": "{{@instrument}}"}, "headers": {"Content-Type": "application/json"}}, "description": "Get candlestick data with invalid/missing parameters"}]}
12	Get Candlestick - Edge Cases	Edge case tests for candlestick data API - boundary conditions and special scenarios	exchange_svc	Reference and Market Data	Candlestick API	{p2,edge_case,market_data,candlestick}	hellen	2025-10-12 10:37:25.239459+00	{"steps": [{"path": "/exchange/v1/public/get-candlestick", "order": 1, "method": "GET", "request": {"body": null, "params": {"count": "{{@count}}", "timeframe": "{{@timeframe}}", "instrument_name": "{{@instrument}}"}, "headers": {"Content-Type": "application/json"}}, "description": "Get candlestick data - edge case scenarios"}]}
19	WebSocket Invalid Channel Subscription	Test WebSocket behavior with invalid channel names	websocket_svc	Websocket Subscriptions	Error Handling	{p2,websocket,negative}	hellen	2025-10-12 14:36:44.309736+00	{"steps": [{"order": 1, "action": "connect", "request": {"url": "{{@ws_url}}"}, "protocol": "websocket", "description": "Connect to WebSocket server"}, {"order": 2, "action": "send", "request": {"body": "{{@message}}"}, "protocol": "websocket", "description": "Send invalid channel subscription"}, {"order": 3, "action": "wait", "request": {"count": 1, "timeout": 10}, "protocol": "websocket", "description": "Wait for error response", "validations": {"notNull": ["$.code"]}}, {"order": 4, "action": "disconnect", "request": {}, "protocol": "websocket", "description": "Disconnect WebSocket"}]}
20	WebSocket Invalid Instrument	Test WebSocket behavior with non-existent instrument names	websocket_svc	Websocket Subscriptions	Error Handling	{p2,websocket,negative}	hellen	2025-10-12 14:36:44.309736+00	{"steps": [{"order": 1, "action": "connect", "request": {"url": "{{@ws_url}}"}, "protocol": "websocket", "description": "Connect to WebSocket server"}, {"order": 2, "action": "send", "request": {"body": "{{@message}}"}, "protocol": "websocket", "description": "Send invalid instrument subscription"}, {"order": 3, "action": "wait", "request": {"count": 1, "timeout": 10}, "protocol": "websocket", "description": "Wait for error response", "validations": {"notNull": ["$.code"]}}, {"order": 4, "action": "disconnect", "request": {}, "protocol": "websocket", "description": "Disconnect WebSocket"}]}
21	WebSocket Malformed Message	Test WebSocket behavior with malformed subscription messages	websocket_svc	Websocket Subscriptions	Error Handling	{p2,websocket,negative}	hellen	2025-10-12 14:36:44.309736+00	{"steps": [{"order": 1, "action": "connect", "request": {"url": "{{@ws_url}}"}, "protocol": "websocket", "description": "Connect to WebSocket server"}, {"order": 2, "action": "send", "request": {"body": "{{@message}}"}, "protocol": "websocket", "description": "Send malformed message"}, {"order": 3, "action": "wait", "request": {"count": 1, "timeout": 10}, "protocol": "websocket", "description": "Wait for error response", "validations": {"notNull": ["$.code"]}}, {"order": 4, "action": "disconnect", "request": {}, "protocol": "websocket", "description": "Disconnect WebSocket"}]}
13	WebSocket Ticker Subscription	Subscribe to ticker data via WebSocket and validate real-time updates (MVP)	websocket_svc	Websocket Subscriptions	Ticker WebSocket API	{p1,websocket,ticker,mvp}	hellen	2025-10-12 13:39:47.719494+00	{"steps": [{"order": 1, "action": "connect", "request": {"url": "{{@ws_url}}"}, "protocol": "websocket", "description": "Connect to WebSocket server"}, {"order": 2, "action": "send", "request": {"body": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["ticker.{{@instrument}}"]}}}, "protocol": "websocket", "description": "Subscribe to ticker channel"}, {"order": 3, "action": "wait", "request": {"count": 1, "timeout": 30}, "protocol": "websocket", "description": "Wait for and validate ticker data", "validations": {"notNull": ["$.i"]}}, {"order": 4, "action": "disconnect", "request": {}, "protocol": "websocket", "description": "Disconnect WebSocket"}]}
10	Get Candlestick - Positive Tests	Test the public candlestick data retrieval API for cryptocurrency trading pairs	exchange_svc	Reference and Market Data	Candlestick API	{p1,smoke,market_data,candlestick}	hellen	2025-10-12 10:37:25.226459+00	{"steps": [{"path": "/exchange/v1/public/get-candlestick", "order": 1, "method": "GET", "request": {"body": null, "params": {"count": "{{@count}}", "timeframe": "{{@timeframe}}", "instrument_name": "{{@instrument}}"}, "headers": {"Content-Type": "application/json"}}, "description": "Get candlestick data from exchange API"}]}
\.


--
-- Data for Name: api_auto_cases_old; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.api_auto_cases_old (id, name, description, service, module, component, tags, author, created_at, parameters) FROM stdin;
11	Get Candlestick - Negative Tests	Negative test cases for candlestick data API - invalid parameters and error handling	exchange_svc	Reference and Market Data	Candlestick API	{p1,negative,market_data,candlestick}	hellen	2025-10-12 10:37:25.23485+00	{"steps": [{"path": "/exchange/v1/public/get-candlestick", "order": 1, "method": "GET", "request": {"body": null, "params": {"count": "{{@count}}", "timeframe": "{{@timeframe}}", "instrument_name": "{{@instrument}}"}, "headers": {"Content-Type": "application/json"}}, "description": "Get candlestick data with invalid/missing parameters"}]}
12	Get Candlestick - Edge Cases	Edge case tests for candlestick data API - boundary conditions and special scenarios	exchange_svc	Reference and Market Data	Candlestick API	{p2,edge_case,market_data,candlestick}	hellen	2025-10-12 10:37:25.239459+00	{"steps": [{"path": "/exchange/v1/public/get-candlestick", "order": 1, "method": "GET", "request": {"body": null, "params": {"count": "{{@count}}", "timeframe": "{{@timeframe}}", "instrument_name": "{{@instrument}}"}, "headers": {"Content-Type": "application/json"}}, "description": "Get candlestick data - edge case scenarios"}]}
19	WebSocket Invalid Channel Subscription	Test WebSocket behavior with invalid channel names	websocket_svc	Websocket Subscriptions	Error Handling	{p2,websocket,negative}	hellen	2025-10-12 14:36:44.309736+00	{"steps": [{"order": 1, "action": "connect", "request": {"url": "{{@ws_url}}"}, "protocol": "websocket", "description": "Connect to WebSocket server"}, {"order": 2, "action": "send", "request": {"body": "{{@message}}"}, "protocol": "websocket", "description": "Send invalid channel subscription"}, {"order": 3, "action": "wait", "request": {"count": 1, "timeout": 10}, "protocol": "websocket", "description": "Wait for error response", "validations": {"notNull": ["$.code"]}}, {"order": 4, "action": "disconnect", "request": {}, "protocol": "websocket", "description": "Disconnect WebSocket"}]}
20	WebSocket Invalid Instrument	Test WebSocket behavior with non-existent instrument names	websocket_svc	Websocket Subscriptions	Error Handling	{p2,websocket,negative}	hellen	2025-10-12 14:36:44.309736+00	{"steps": [{"order": 1, "action": "connect", "request": {"url": "{{@ws_url}}"}, "protocol": "websocket", "description": "Connect to WebSocket server"}, {"order": 2, "action": "send", "request": {"body": "{{@message}}"}, "protocol": "websocket", "description": "Send invalid instrument subscription"}, {"order": 3, "action": "wait", "request": {"count": 1, "timeout": 10}, "protocol": "websocket", "description": "Wait for error response", "validations": {"notNull": ["$.code"]}}, {"order": 4, "action": "disconnect", "request": {}, "protocol": "websocket", "description": "Disconnect WebSocket"}]}
21	WebSocket Malformed Message	Test WebSocket behavior with malformed subscription messages	websocket_svc	Websocket Subscriptions	Error Handling	{p2,websocket,negative}	hellen	2025-10-12 14:36:44.309736+00	{"steps": [{"order": 1, "action": "connect", "request": {"url": "{{@ws_url}}"}, "protocol": "websocket", "description": "Connect to WebSocket server"}, {"order": 2, "action": "send", "request": {"body": "{{@message}}"}, "protocol": "websocket", "description": "Send malformed message"}, {"order": 3, "action": "wait", "request": {"count": 1, "timeout": 10}, "protocol": "websocket", "description": "Wait for error response", "validations": {"notNull": ["$.code"]}}, {"order": 4, "action": "disconnect", "request": {}, "protocol": "websocket", "description": "Disconnect WebSocket"}]}
13	WebSocket Ticker Subscription	Subscribe to ticker data via WebSocket and validate real-time updates (MVP)	websocket_svc	Websocket Subscriptions	Ticker WebSocket API	{p1,websocket,ticker,mvp}	hellen	2025-10-12 13:39:47.719494+00	{"steps": [{"order": 1, "action": "connect", "request": {"url": "{{@ws_url}}"}, "protocol": "websocket", "description": "Connect to WebSocket server"}, {"order": 2, "action": "send", "request": {"body": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["ticker.{{@instrument}}"]}}}, "protocol": "websocket", "description": "Subscribe to ticker channel"}, {"order": 3, "action": "wait", "request": {"count": 1, "timeout": 30}, "protocol": "websocket", "description": "Wait for and validate ticker data", "validations": {"notNull": ["$.i"]}}, {"order": 4, "action": "disconnect", "request": {}, "protocol": "websocket", "description": "Disconnect WebSocket"}]}
10	Get Candlestick - Positive Tests	Test the public candlestick data retrieval API for cryptocurrency trading pairs	exchange_svc	Reference and Market Data	Candlestick API	{p1,smoke,market_data,candlestick}	hellen	2025-10-12 10:37:25.226459+00	{"steps": [{"path": "/exchange/v1/public/get-candlestick", "order": 1, "method": "GET", "request": {"body": null, "params": {"count": "{{@count}}", "timeframe": "{{@timeframe}}", "instrument_name": "{{@instrument}}"}, "headers": {"Content-Type": "application/json"}}, "description": "Get candlestick data from exchange API"}]}
\.


--
-- Data for Name: auto_case_audit; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auto_case_audit (id, runid, case_id, data_set_id, scenario, issue_key, run_status, duration, error_message, variables, update_at) FROM stdin;
2790	06d43d60-f090-415c-9bcc-06545952d711	12	\N	REST_Candlestick_DataConsistency_Exception	TC_R045	passed	2.0134752	\N	{}	2025-10-15 12:07:05.192279+00
\.


--
-- Data for Name: auto_progress; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auto_progress (id, runid, version_id, component, total_cases, passes, failures, skips, begin_time, end_time, releaseversion, task_status, run_by, label, runmode, profile, update_time) FROM stdin;
\.


--
-- Data for Name: auto_test_audit; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.auto_test_audit (id, audit_case_id, step_order, action_description, request_details, response_details, step_status) FROM stdin;
\.


--
-- Data for Name: case_data_sets_backup; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.case_data_sets_backup (id, case_id, data_set_name, variables, validations_override, environments, jira_id, tags, is_active) FROM stdin;
109	10	SP04: 2h Two Hours	{"count": 100, "timeframe": "2h", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "2h", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
111	10	SP06: 12h Half Day	{"count": 100, "timeframe": "12h", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "12h", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
112	10	SP07: 7D Weekly	{"count": 52, "timeframe": "7D", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "7D", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
18	13	Subscribe to BTCUSD-PERP ticker	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "instrument": "BTCUSD-PERP"}	{"3": {"body": {"code": 0, "result": {"data": [{"i": "BTCUSD-PERP"}], "channel": "ticker", "instrument_name": "BTCUSD-PERP"}}, "notNull": ["$.result", "$.result.instrument_name", "$.result.channel", "$.result.data", "$.result.data[0].i", "$.result.data[0].h", "$.result.data[0].l", "$.result.data[0].a", "$.result.data[0].v", "$.result.data[0].vv", "$.result.data[0].c", "$.result.data[0].oi", "$.result.data[0].t"], "notExist": ["$.error"]}}	{uat}	PROJ-WS-001	{smoke,websocket,btc}	t
36	21	Malformed - invalid method name	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 5, "method": "invalid_method", "params": {"channels": ["ticker.BTCUSD-PERP"]}}, "malformed_message": {"id": 5, "method": "invalid_method", "params": {"channels": ["ticker.BTCUSD-PERP"]}}}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,invalid_method}	t
29	19	Invalid channel - empty string	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": []}}, "invalid_channel": ""}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,edge_case}	t
131	12	Case sensitive - lowercase	{"count": 10, "timeframe": "1h", "instrument": "btc_usd"}	{"1": {"body": {"code": 40004, "message": "Invalid instrument_name"}, "expectedStatusCode": 400}}	{uat}	\N	{edge_case,validation,candlestick}	t
19	13	Subscribe to ETHUSD-PERP ticker	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "instrument": "ETHUSD-PERP"}	{"3": {"body": {"code": 0, "result": {"data": [{"i": "ETHUSD-PERP"}], "channel": "ticker", "instrument_name": "ETHUSD-PERP"}}, "notNull": ["$.result", "$.result.instrument_name", "$.result.channel", "$.result.data", "$.result.data[0].i", "$.result.data[0].h", "$.result.data[0].l", "$.result.data[0].a", "$.result.data[0].v", "$.result.data[0].vv", "$.result.data[0].c", "$.result.data[0].oi", "$.result.data[0].t"], "notExist": ["$.error"]}}	{uat}	\N	{smoke,websocket,eth}	t
102	10	OT03: BTC 1D Large Month	{"count": 1000, "timeframe": "1D", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1D", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
103	10	OT04: ETH 1m Medium Month	{"count": 100, "timeframe": "1m", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1m", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
110	10	SP05: 4h Important Swing	{"count": 100, "timeframe": "4h", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "4h", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
31	20	Invalid instrument - missing suffix	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["ticker.BTCUSD"]}}, "instrument": "BTCUSD"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,invalid_instrument}	t
97	10	OT07: XRP 1m Large Day	{"count": 1000, "timeframe": "1m", "instrument": "BTC_USDT"}	{"1": {"body": {"code": 0, "result": {"interval": "1m", "instrument_name": "BTC_USDT"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
98	10	OT08: XRP 1h Small Month	{"count": 1, "timeframe": "1h", "instrument": "BTC_USDT"}	{"1": {"body": {"code": 0, "result": {"interval": "1h", "instrument_name": "BTC_USDT"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
99	10	OT09: XRP 1D Medium Hour	{"count": 100, "timeframe": "1D", "instrument": "BTC_USDT"}	{"1": {"body": {"code": 0, "result": {"interval": "1D", "instrument_name": "BTC_USDT"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
100	10	OT01: BTC 1m Minimal Hour	{"count": 1, "timeframe": "1m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1m", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,smoke}	t
27	19	Invalid channel - random string	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["totally_invalid_channel_name"]}}, "invalid_channel": "totally_invalid_channel_name"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,invalid_channel}	t
28	19	Invalid channel - wrong type	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["invalid_type.BTCUSD-PERP"]}}, "invalid_channel": "invalid_type.BTCUSD-PERP"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,invalid_channel}	t
30	20	Invalid instrument - does not exist	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["ticker.FAKECOIN-PERP"]}}, "instrument": "FAKECOIN-PERP"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,invalid_instrument}	t
32	20	Invalid instrument - lowercase	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["ticker.btcusd-perp"]}}, "instrument": "btcusd-perp"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,case_sensitive}	t
33	20	Invalid instrument - special characters	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["ticker.BTC@USD-PERP"]}}, "instrument": "BTC@USD-PERP"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,edge_case}	t
116	11	NT04: Excessive Count	{"count": 10000, "timeframe": "1m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "method": "public/get-candlestick"}, "expectedStatusCode": 200}}	{uat}	\N	{negative,candlestick,error_handling}	t
117	11	NT01: Invalid Instrument	{"count": 100, "timeframe": "1h", "instrument": "INVALID_PAIR"}	{"1": {"body": {"code": 40004, "message": "Invalid instrument_name"}, "expectedStatusCode": 400}}	{uat}	\N	{negative,candlestick,error_handling}	t
120	11	NT05: Case Sensitive	{"count": 100, "timeframe": "1H", "instrument": "btc_usd"}	{"1": {"body": {"code": 40004, "message": "Invalid instrument_name"}, "expectedStatusCode": 400}}	{uat}	\N	{negative,candlestick,error_handling}	t
119	11	NT03: Negative Count	{"count": -1, "timeframe": "1h", "instrument": "BTC_USD"}	{"1": {"body": {"code": 40004, "message": "Count must be positive"}, "expectedStatusCode": 400}}	{uat}	\N	{negative,candlestick,error_handling}	t
118	11	NT02: Invalid Timeframe	{"count": 100, "timeframe": "INVALID", "instrument": "BTC_USD"}	{"1": {"body": {"code": 40003, "message": "Invalid request"}, "expectedStatusCode": 400}}	{uat}	\N	{negative,candlestick,error_handling}	t
104	10	OT05: ETH 1h Large Hour	{"count": 1000, "timeframe": "1h", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1h", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
105	10	OT06: ETH 1D Small Day	{"count": 1, "timeframe": "1D", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1D", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,smoke}	t
106	10	SP01: 5min Common Trading	{"count": 100, "timeframe": "5m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "5m", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
107	10	SP02: 15min Standard	{"count": 100, "timeframe": "15m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "15m", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
108	10	SP03: 30min Half Hour	{"count": 100, "timeframe": "30m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "30m", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
101	10	OT02: BTC 1h Medium Day	{"count": 100, "timeframe": "1h", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1h", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
113	10	SP08: 14D Bi-weekly	{"count": 26, "timeframe": "14D", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "14D", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
114	10	SP09: 1M Monthly	{"count": 12, "timeframe": "1M", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1M", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
115	10	SP10: 5min Performance	{"count": 1000, "timeframe": "5m", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "5m", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
127	12	Minimum timeframe - 1m	{"count": 100, "timeframe": "1m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1m", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,boundary,candlestick}	t
128	12	Maximum timeframe - 1M	{"count": 50, "timeframe": "1M", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1M", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,boundary,candlestick}	t
130	12	Maximum count - 5000	{"count": 5000, "timeframe": "1m", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1m", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,boundary,candlestick,performance}	t
132	12	Different pair - BTC_USDT	{"count": 200, "timeframe": "4h", "instrument": "BTC_USDT"}	{"1": {"body": {"code": 0, "result": {"interval": "4h", "instrument_name": "BTC_USDT"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,candlestick}	t
133	12	Medium timeframe - 1h	{"count": 500, "timeframe": "1h", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1h", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,candlestick}	t
136	12	Decimal count - 100.5	{"count": 100, "timeframe": "1D", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1D", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,boundary,candlestick}	t
34	21	Malformed - missing method field	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 3, "params": {"channels": ["ticker.BTCUSD-PERP"]}}, "malformed_message": {"id": 3, "params": {"channels": ["ticker.BTCUSD-PERP"]}}}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,malformed}	t
35	21	Malformed - missing params field	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 4, "method": "subscribe"}, "malformed_message": {"id": 4, "method": "subscribe"}}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,malformed}	t
\.


--
-- Data for Name: case_data_sets_old; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.case_data_sets_old (id, case_id, data_set_name, variables, validations_override, environments, jira_id, tags, is_active) FROM stdin;
109	10	SP04: 2h Two Hours	{"count": 100, "timeframe": "2h", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "2h", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
111	10	SP06: 12h Half Day	{"count": 100, "timeframe": "12h", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "12h", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
112	10	SP07: 7D Weekly	{"count": 52, "timeframe": "7D", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "7D", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
18	13	Subscribe to BTCUSD-PERP ticker	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "instrument": "BTCUSD-PERP"}	{"3": {"body": {"code": 0, "result": {"data": [{"i": "BTCUSD-PERP"}], "channel": "ticker", "instrument_name": "BTCUSD-PERP"}}, "notNull": ["$.result", "$.result.instrument_name", "$.result.channel", "$.result.data", "$.result.data[0].i", "$.result.data[0].h", "$.result.data[0].l", "$.result.data[0].a", "$.result.data[0].v", "$.result.data[0].vv", "$.result.data[0].c", "$.result.data[0].oi", "$.result.data[0].t"], "notExist": ["$.error"]}}	{uat}	PROJ-WS-001	{smoke,websocket,btc}	t
36	21	Malformed - invalid method name	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 5, "method": "invalid_method", "params": {"channels": ["ticker.BTCUSD-PERP"]}}, "malformed_message": {"id": 5, "method": "invalid_method", "params": {"channels": ["ticker.BTCUSD-PERP"]}}}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,invalid_method}	t
29	19	Invalid channel - empty string	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": []}}, "invalid_channel": ""}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,edge_case}	t
131	12	Case sensitive - lowercase	{"count": 10, "timeframe": "1h", "instrument": "btc_usd"}	{"1": {"body": {"code": 40004, "message": "Invalid instrument_name"}, "expectedStatusCode": 400}}	{uat}	\N	{edge_case,validation,candlestick}	t
19	13	Subscribe to ETHUSD-PERP ticker	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "instrument": "ETHUSD-PERP"}	{"3": {"body": {"code": 0, "result": {"data": [{"i": "ETHUSD-PERP"}], "channel": "ticker", "instrument_name": "ETHUSD-PERP"}}, "notNull": ["$.result", "$.result.instrument_name", "$.result.channel", "$.result.data", "$.result.data[0].i", "$.result.data[0].h", "$.result.data[0].l", "$.result.data[0].a", "$.result.data[0].v", "$.result.data[0].vv", "$.result.data[0].c", "$.result.data[0].oi", "$.result.data[0].t"], "notExist": ["$.error"]}}	{uat}	\N	{smoke,websocket,eth}	t
102	10	OT03: BTC 1D Large Month	{"count": 1000, "timeframe": "1D", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1D", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
103	10	OT04: ETH 1m Medium Month	{"count": 100, "timeframe": "1m", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1m", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
110	10	SP05: 4h Important Swing	{"count": 100, "timeframe": "4h", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "4h", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
31	20	Invalid instrument - missing suffix	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["ticker.BTCUSD"]}}, "instrument": "BTCUSD"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,invalid_instrument}	t
97	10	OT07: XRP 1m Large Day	{"count": 1000, "timeframe": "1m", "instrument": "BTC_USDT"}	{"1": {"body": {"code": 0, "result": {"interval": "1m", "instrument_name": "BTC_USDT"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
98	10	OT08: XRP 1h Small Month	{"count": 1, "timeframe": "1h", "instrument": "BTC_USDT"}	{"1": {"body": {"code": 0, "result": {"interval": "1h", "instrument_name": "BTC_USDT"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
99	10	OT09: XRP 1D Medium Hour	{"count": 100, "timeframe": "1D", "instrument": "BTC_USDT"}	{"1": {"body": {"code": 0, "result": {"interval": "1D", "instrument_name": "BTC_USDT"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
100	10	OT01: BTC 1m Minimal Hour	{"count": 1, "timeframe": "1m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1m", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,smoke}	t
27	19	Invalid channel - random string	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["totally_invalid_channel_name"]}}, "invalid_channel": "totally_invalid_channel_name"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,invalid_channel}	t
28	19	Invalid channel - wrong type	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["invalid_type.BTCUSD-PERP"]}}, "invalid_channel": "invalid_type.BTCUSD-PERP"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,invalid_channel}	t
30	20	Invalid instrument - does not exist	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["ticker.FAKECOIN-PERP"]}}, "instrument": "FAKECOIN-PERP"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,invalid_instrument}	t
32	20	Invalid instrument - lowercase	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["ticker.btcusd-perp"]}}, "instrument": "btcusd-perp"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,case_sensitive}	t
33	20	Invalid instrument - special characters	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 1, "nonce": 1760370900000, "method": "subscribe", "params": {"channels": ["ticker.BTC@USD-PERP"]}}, "instrument": "BTC@USD-PERP"}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,edge_case}	t
116	11	NT04: Excessive Count	{"count": 10000, "timeframe": "1m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "method": "public/get-candlestick"}, "expectedStatusCode": 200}}	{uat}	\N	{negative,candlestick,error_handling}	t
117	11	NT01: Invalid Instrument	{"count": 100, "timeframe": "1h", "instrument": "INVALID_PAIR"}	{"1": {"body": {"code": 40004, "message": "Invalid instrument_name"}, "expectedStatusCode": 400}}	{uat}	\N	{negative,candlestick,error_handling}	t
120	11	NT05: Case Sensitive	{"count": 100, "timeframe": "1H", "instrument": "btc_usd"}	{"1": {"body": {"code": 40004, "message": "Invalid instrument_name"}, "expectedStatusCode": 400}}	{uat}	\N	{negative,candlestick,error_handling}	t
119	11	NT03: Negative Count	{"count": -1, "timeframe": "1h", "instrument": "BTC_USD"}	{"1": {"body": {"code": 40004, "message": "Count must be positive"}, "expectedStatusCode": 400}}	{uat}	\N	{negative,candlestick,error_handling}	t
118	11	NT02: Invalid Timeframe	{"count": 100, "timeframe": "INVALID", "instrument": "BTC_USD"}	{"1": {"body": {"code": 40003, "message": "Invalid request"}, "expectedStatusCode": 400}}	{uat}	\N	{negative,candlestick,error_handling}	t
104	10	OT05: ETH 1h Large Hour	{"count": 1000, "timeframe": "1h", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1h", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
105	10	OT06: ETH 1D Small Day	{"count": 1, "timeframe": "1D", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1D", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,smoke}	t
106	10	SP01: 5min Common Trading	{"count": 100, "timeframe": "5m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "5m", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
107	10	SP02: 15min Standard	{"count": 100, "timeframe": "15m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "15m", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
108	10	SP03: 30min Half Hour	{"count": 100, "timeframe": "30m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "30m", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
101	10	OT02: BTC 1h Medium Day	{"count": 100, "timeframe": "1h", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1h", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
113	10	SP08: 14D Bi-weekly	{"count": 26, "timeframe": "14D", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "14D", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
114	10	SP09: 1M Monthly	{"count": 12, "timeframe": "1M", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1M", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
115	10	SP10: 5min Performance	{"count": 1000, "timeframe": "5m", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "5m", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{positive,candlestick,regression}	t
127	12	Minimum timeframe - 1m	{"count": 100, "timeframe": "1m", "instrument": "BTC_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1m", "instrument_name": "BTC_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,boundary,candlestick}	t
128	12	Maximum timeframe - 1M	{"count": 50, "timeframe": "1M", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1M", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,boundary,candlestick}	t
130	12	Maximum count - 5000	{"count": 5000, "timeframe": "1m", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1m", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,boundary,candlestick,performance}	t
132	12	Different pair - BTC_USDT	{"count": 200, "timeframe": "4h", "instrument": "BTC_USDT"}	{"1": {"body": {"code": 0, "result": {"interval": "4h", "instrument_name": "BTC_USDT"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,candlestick}	t
133	12	Medium timeframe - 1h	{"count": 500, "timeframe": "1h", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1h", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,candlestick}	t
136	12	Decimal count - 100.5	{"count": 100, "timeframe": "1D", "instrument": "ETH_USD"}	{"1": {"body": {"code": 0, "result": {"interval": "1D", "instrument_name": "ETH_USD"}}, "notNull": ["$.result", "$.result.interval", "$.result.instrument_name", "$.result.data"], "notExist": ["$.error"], "expectedStatusCode": 200}}	{uat}	\N	{edge_case,boundary,candlestick}	t
34	21	Malformed - missing method field	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 3, "params": {"channels": ["ticker.BTCUSD-PERP"]}}, "malformed_message": {"id": 3, "params": {"channels": ["ticker.BTCUSD-PERP"]}}}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,malformed}	t
35	21	Malformed - missing params field	{"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "message": {"id": 4, "method": "subscribe"}, "malformed_message": {"id": 4, "method": "subscribe"}}	{"3": {"body": {"code": 40003}, "notNull": ["$.code"], "notExist": ["$.result"]}}	{uat}	\N	{negative,malformed}	t
\.


--
-- Data for Name: test_environments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.test_environments (id, name, service, base_url, description, is_active) FROM stdin;
1	dev	user_svc	http://127.0.0.1:8788	Development - User service	t
2	dev	exchange_svc	https://dev-api.3ona.co	Development - Exchange service	t
3	dev	websocket_svc	wss://dev-stream.3ona.co/exchange/v1/market	Development - WebSocket service	t
4	uat	user_svc	http://127.0.0.1:8787	UAT - User service	t
6	uat	websocket_svc	wss://uat-stream.3ona.co/exchange/v1/market	UAT - WebSocket service	t
5	uat	exchange_svc	https://uat-api.3ona.co/exchange/v1	UAT - Exchange service	t
\.


--
-- Data for Name: test_environments_old_20251013; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.test_environments_old_20251013 (id, name, base_url, app_db_connection_string, description, is_active, services, service) FROM stdin;
2	dev	http://127.0.0.1:8788	postgresql://admin:password@localhost:5433/postgres	Development environment	t	{"user_svc": {"base_url": "http://127.0.0.1:8788", "description": "User service API"}, "exchange_svc": {"ws_url": "wss://dev-stream.3ona.co/exchange/v1/market", "base_url": "https://dev-api.3ona.co", "description": "Exchange service REST API"}, "websocket_svc": {"ws_url": "wss://dev-stream.3ona.co/exchange/v1/market", "description": "Exchange WebSocket service"}}	\N
1	uat	http://127.0.0.1:8787	postgresql://admin:password@localhost:5434/postgres	UAT environment	t	{"user_svc": {"base_url": "http://127.0.0.1:8787", "description": "User service API"}, "exchange_svc": {"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "base_url": "https://uat-api.3ona.co", "description": "Exchange service REST API"}, "websocket_svc": {"ws_url": "wss://uat-stream.3ona.co/exchange/v1/market", "description": "Exchange WebSocket service"}}	\N
\.


--
-- Name: api_auto_cases_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.api_auto_cases_id_seq', 24, true);


--
-- Name: api_auto_cases_new_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.api_auto_cases_new_id_seq', 12, true);


--
-- Name: auto_case_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auto_case_audit_id_seq', 2790, true);


--
-- Name: auto_progress_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auto_progress_id_seq', 989, true);


--
-- Name: auto_test_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.auto_test_audit_id_seq', 6, true);


--
-- Name: case_data_sets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.case_data_sets_id_seq', 136, true);


--
-- Name: test_environments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.test_environments_id_seq', 6, true);


--
-- Name: api_auto_cases api_auto_cases_new_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_auto_cases
    ADD CONSTRAINT api_auto_cases_new_pkey PRIMARY KEY (id);


--
-- Name: api_auto_cases_old api_auto_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_auto_cases_old
    ADD CONSTRAINT api_auto_cases_pkey PRIMARY KEY (id);


--
-- Name: auto_case_audit auto_case_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auto_case_audit
    ADD CONSTRAINT auto_case_audit_pkey PRIMARY KEY (id);


--
-- Name: auto_progress auto_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auto_progress
    ADD CONSTRAINT auto_progress_pkey PRIMARY KEY (id);


--
-- Name: auto_test_audit auto_test_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auto_test_audit
    ADD CONSTRAINT auto_test_audit_pkey PRIMARY KEY (id);


--
-- Name: case_data_sets_old case_data_sets_jira_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.case_data_sets_old
    ADD CONSTRAINT case_data_sets_jira_id_key UNIQUE (jira_id);


--
-- Name: case_data_sets_old case_data_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.case_data_sets_old
    ADD CONSTRAINT case_data_sets_pkey PRIMARY KEY (id);


--
-- Name: test_environments test_environments_name_service_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_environments
    ADD CONSTRAINT test_environments_name_service_key UNIQUE (name, service);


--
-- Name: test_environments test_environments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.test_environments
    ADD CONSTRAINT test_environments_pkey PRIMARY KEY (id);


--
-- Name: api_auto_cases unique_jira_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.api_auto_cases
    ADD CONSTRAINT unique_jira_id UNIQUE (jira_id);


--
-- Name: idx_api_auto_cases_parameters; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_api_auto_cases_parameters ON public.api_auto_cases_old USING gin (parameters);


--
-- Name: idx_cases_component; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cases_component ON public.api_auto_cases USING btree (component) WHERE (enable = true);


--
-- Name: idx_cases_environments; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cases_environments ON public.api_auto_cases USING gin (environments) WHERE (enable = true);


--
-- Name: idx_cases_jira; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cases_jira ON public.api_auto_cases USING btree (jira_id) WHERE (enable = true);


--
-- Name: idx_cases_module; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cases_module ON public.api_auto_cases USING btree (module) WHERE (enable = true);


--
-- Name: idx_cases_service; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cases_service ON public.api_auto_cases USING btree (service) WHERE (enable = true);


--
-- Name: idx_cases_tags; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cases_tags ON public.api_auto_cases USING gin (tags) WHERE (enable = true);


--
-- Name: ix_api_auto_cases_component; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_api_auto_cases_component ON public.api_auto_cases_old USING btree (component);


--
-- Name: ix_api_auto_cases_module; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_api_auto_cases_module ON public.api_auto_cases_old USING btree (module);


--
-- Name: ix_api_auto_cases_service; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_api_auto_cases_service ON public.api_auto_cases_old USING btree (service);


--
-- Name: ix_api_auto_cases_tags; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_api_auto_cases_tags ON public.api_auto_cases_old USING btree (tags);


--
-- Name: ix_auto_case_audit_runid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_auto_case_audit_runid ON public.auto_case_audit USING btree (runid);


--
-- Name: ix_case_data_sets_environments; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_case_data_sets_environments ON public.case_data_sets_old USING btree (environments);


--
-- Name: api_auto_cases trigger_update_api_auto_cases_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_api_auto_cases_updated_at BEFORE UPDATE ON public.api_auto_cases FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: auto_test_audit auto_test_audit_audit_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.auto_test_audit
    ADD CONSTRAINT auto_test_audit_audit_case_id_fkey FOREIGN KEY (audit_case_id) REFERENCES public.auto_case_audit(id);


--
-- Name: case_data_sets_old case_data_sets_case_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.case_data_sets_old
    ADD CONSTRAINT case_data_sets_case_id_fkey FOREIGN KEY (case_id) REFERENCES public.api_auto_cases_old(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

