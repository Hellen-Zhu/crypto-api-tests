-- ====================================================================
-- 快速参考 SQL - 常用操作速查表
-- ====================================================================
-- 本文件包含最常用的 SQL 操作，可直接复制使用
-- ====================================================================

-- ====================================================================
-- 📊 查询操作
-- ====================================================================

-- 1. 查看所有测试用例
SELECT
    id,
    name,
    service,
    module,
    tags,
    created_at
FROM api_auto_cases
ORDER BY id DESC
LIMIT 20;

-- 2. 查看测试用例详情（包含数据集数量）
SELECT
    ac.id,
    ac.name AS case_name,
    ac.service,
    ac.module,
    COUNT(cds.id) AS dataset_count,
    STRING_AGG(DISTINCT cds.data_set_name, ', ') AS datasets
FROM api_auto_cases ac
LEFT JOIN case_data_sets cds ON cds.case_id = ac.id
GROUP BY ac.id, ac.name, ac.service, ac.module
ORDER BY ac.id DESC
LIMIT 10;

-- 3. 按服务查询测试用例
SELECT id, name, module, tags
FROM api_auto_cases
WHERE service = 'exchange_svc'  -- 修改服务名
ORDER BY id;

-- 4. 按标签查询测试用例
SELECT id, name, service, tags
FROM api_auto_cases
WHERE tags && ARRAY['smoke']  -- 修改标签
ORDER BY id;

-- 5. 查看特定测试用例的所有数据集
SELECT
    cds.id AS dataset_id,
    cds.data_set_name,
    cds.variables,
    cds.environments,
    cds.tags,
    cds.is_active
FROM case_data_sets cds
WHERE cds.case_id = 100  -- 修改 case_id
ORDER BY cds.id;

-- 6. 查看测试用例的步骤定义
SELECT
    id,
    name,
    jsonb_pretty(parameters) AS formatted_steps
FROM api_auto_cases
WHERE id = 100;  -- 修改 case_id

-- 7. 查看所有环境配置
SELECT
    id,
    name,
    base_url,
    is_active,
    description
FROM test_environments
ORDER BY id;

-- 8. 查询最近创建的测试用例
SELECT
    id,
    name,
    service,
    created_at
FROM api_auto_cases
ORDER BY created_at DESC
LIMIT 5;

-- 9. 搜索测试用例（按名称）
SELECT id, name, service, module
FROM api_auto_cases
WHERE name ILIKE '%ticker%'  -- 修改搜索关键字
ORDER BY id;

-- 10. 查看数据集的验证覆盖情况
SELECT
    cds.id,
    cds.data_set_name,
    CASE
        WHEN cds.validations_override IS NULL THEN '使用默认'
        ELSE '已覆盖'
    END AS validation_status,
    jsonb_pretty(cds.validations_override) AS override_rules
FROM case_data_sets cds
WHERE cds.case_id = 100;  -- 修改 case_id

-- ====================================================================
-- 📝 创建操作
-- ====================================================================

-- 11. 快速创建简单的 GET 请求测试用例
INSERT INTO api_auto_cases (
    name,
    service,
    module,
    tags,
    author,
    parameters
) VALUES (
    '【修改】测试用例名称',
    '【修改】服务名',
    '【修改】模块名',
    ARRAY['【修改】标签'],
    'test_team',
    '{
      "steps": [{
        "order": 1,
        "description": "【修改】步骤描述",
        "path": "【修改】/api/path",
        "method": "GET",
        "request": {
          "params": {"key": "{{@value}}"},
          "headers": {"Content-Type": "application/json"},
          "body": null
        },
        "validations": {
          "expectedStatusCode": 200,
          "notNull": ["$.code"],
          "body": {"code": 0}
        },
        "outputs": null
      }]
    }'::jsonb
)
RETURNING id;

-- 12. 快速创建数据集
INSERT INTO case_data_sets (
    case_id,
    data_set_name,
    variables,
    environments,
    tags,
    is_active
) VALUES (
    【填入case_id】,
    '【修改】数据集名称',
    '{"【修改】变量名": "【修改】变量值"}'::jsonb,
    ARRAY['uat'],
    ARRAY['smoke'],
    true
);

-- ====================================================================
-- 🔄 复制操作
-- ====================================================================

-- 13. 复制测试用例（不含数据集）
INSERT INTO api_auto_cases (
    name,
    description,
    service,
    module,
    component,
    tags,
    author,
    parameters
)
SELECT
    name || ' - Copy',
    description,
    service,
    module,
    component,
    tags,
    author,
    parameters
FROM api_auto_cases
WHERE id = 10  -- 修改源 case_id
RETURNING id;

-- 14. 复制数据集到新测试用例
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
    【填入新的case_id】,  -- 目标 case_id
    data_set_name,
    variables,
    validations_override,
    environments,
    jira_id,
    tags,
    is_active
FROM case_data_sets
WHERE case_id = 10;  -- 源 case_id

-- 15. 完全克隆测试用例（含所有数据集）
WITH new_case AS (
    INSERT INTO api_auto_cases (name, description, service, module, tags, author, parameters)
    SELECT
        name || ' - Clone',
        description,
        service,
        module,
        tags,
        author,
        parameters
    FROM api_auto_cases
    WHERE id = 10  -- 源 case_id
    RETURNING id
)
INSERT INTO case_data_sets (case_id, data_set_name, variables, validations_override, environments, tags, is_active)
SELECT
    nc.id,
    cds.data_set_name,
    cds.variables,
    cds.validations_override,
    cds.environments,
    cds.tags,
    cds.is_active
FROM new_case nc, case_data_sets cds
WHERE cds.case_id = 10;  -- 源 case_id

-- ====================================================================
-- ✏️ 更新操作
-- ====================================================================

-- 16. 更新测试用例名称和描述
UPDATE api_auto_cases
SET
    name = '【修改】新名称',
    description = '【修改】新描述'
WHERE id = 100;

-- 17. 添加/修改标签
-- 添加标签
UPDATE api_auto_cases
SET tags = tags || ARRAY['new_tag']
WHERE id = 100;

-- 替换标签
UPDATE api_auto_cases
SET tags = ARRAY['tag1', 'tag2']
WHERE id = 100;

-- 18. 更新数据集变量
-- 添加新变量
UPDATE case_data_sets
SET variables = variables || '{"new_var": "new_value"}'::jsonb
WHERE id = 50;

-- 修改现有变量
UPDATE case_data_sets
SET variables = jsonb_set(variables, '{existing_var}', '"new_value"')
WHERE id = 50;

-- 19. 更新验证规则覆盖
UPDATE case_data_sets
SET validations_override = '{
    "1": {
        "expectedStatusCode": 400,
        "body": {"code": 40004},
        "notNull": ["$.code", "$.message"]
    }
}'::jsonb
WHERE id = 50;

-- 20. 修改运行环境
UPDATE case_data_sets
SET environments = ARRAY['uat', 'dev']
WHERE id = 50;

-- 21. 批量更新环境（按 case_id）
UPDATE case_data_sets
SET environments = ARRAY['exchange_uat']
WHERE case_id = 100;

-- ====================================================================
-- 🗑️ 删除操作
-- ====================================================================

-- 22. 删除单个数据集
DELETE FROM case_data_sets
WHERE id = 50;

-- 23. 删除测试用例（级联删除所有数据集）
DELETE FROM api_auto_cases
WHERE id = 100;

-- 24. 删除特定服务的所有测试用例
DELETE FROM api_auto_cases
WHERE service = 'old_service';

-- 25. 清理未激活的数据集
DELETE FROM case_data_sets
WHERE is_active = false;

-- ====================================================================
-- 🔧 维护操作
-- ====================================================================

-- 26. 禁用/启用测试用例的所有数据集
-- 禁用
UPDATE case_data_sets
SET is_active = false
WHERE case_id = 100;

-- 启用
UPDATE case_data_sets
SET is_active = true
WHERE case_id = 100;

-- 27. 批量修改数据集状态（按标签）
UPDATE case_data_sets
SET is_active = false
WHERE tags && ARRAY['deprecated'];

-- 28. 清理 NULL 的验证覆盖
UPDATE case_data_sets
SET validations_override = null
WHERE validations_override = 'null'::jsonb;

-- 29. 统一修改服务名
UPDATE api_auto_cases
SET service = 'new_service_name'
WHERE service = 'old_service_name';

-- 30. 添加 Jira ID
UPDATE case_data_sets
SET jira_id = 'PROJ-【编号】'
WHERE id = 50;

-- ====================================================================
-- 📈 批量操作
-- ====================================================================

-- 31. 批量创建数据集（多个场景）
INSERT INTO case_data_sets (case_id, data_set_name, variables, environments, tags, is_active)
VALUES
    (100, 'Scenario 1', '{"param": "value1"}'::jsonb, ARRAY['uat'], ARRAY['smoke'], true),
    (100, 'Scenario 2', '{"param": "value2"}'::jsonb, ARRAY['uat'], ARRAY['smoke'], true),
    (100, 'Scenario 3', '{"param": "value3"}'::jsonb, ARRAY['uat'], ARRAY['smoke'], true);

-- 32. 批量更新参数（相同 case_id）
UPDATE case_data_sets
SET variables = jsonb_set(variables, '{common_param}', '"common_value"')
WHERE case_id = 100;

-- 33. 批量添加环境
UPDATE case_data_sets
SET environments = environments || ARRAY['dev']
WHERE case_id = 100 AND 'dev' != ALL(environments);

-- ====================================================================
-- 🔍 诊断和调试
-- ====================================================================

-- 34. 检查 parameters 结构是否正确
SELECT
    id,
    name,
    CASE
        WHEN parameters IS NULL THEN 'ERROR: NULL'
        WHEN NOT (parameters ? 'steps') THEN 'ERROR: No steps key'
        WHEN jsonb_typeof(parameters->'steps') != 'array' THEN 'ERROR: steps not array'
        WHEN jsonb_array_length(parameters->'steps') = 0 THEN 'ERROR: Empty steps'
        ELSE 'OK'
    END AS structure_status,
    jsonb_array_length(parameters->'steps') AS step_count
FROM api_auto_cases
ORDER BY id DESC
LIMIT 10;

-- 35. 检查数据集变量是否完整
SELECT
    cds.id,
    cds.data_set_name,
    ac.parameters->'steps'->0->'request' AS request_config,
    cds.variables,
    -- 提取所有占位符
    regexp_matches(ac.parameters::text, '\{\{@(\w+)\}\}', 'g') AS placeholders
FROM case_data_sets cds
JOIN api_auto_cases ac ON ac.id = cds.case_id
WHERE cds.case_id = 100;

-- 36. 查找使用特定变量的数据集
SELECT
    id,
    data_set_name,
    variables
FROM case_data_sets
WHERE variables ? '【变量名】'  -- 检查是否包含某个变量
ORDER BY id;

-- 37. 统计测试覆盖率
SELECT
    service,
    COUNT(DISTINCT ac.id) AS case_count,
    COUNT(cds.id) AS dataset_count,
    COUNT(DISTINCT ac.module) AS module_count
FROM api_auto_cases ac
LEFT JOIN case_data_sets cds ON cds.case_id = ac.id
GROUP BY service
ORDER BY case_count DESC;

-- 38. 查找未激活的数据集
SELECT
    cds.id,
    ac.name AS case_name,
    cds.data_set_name,
    cds.is_active
FROM case_data_sets cds
JOIN api_auto_cases ac ON ac.id = cds.case_id
WHERE cds.is_active = false
ORDER BY cds.id;

-- 39. 检查验证覆盖率
SELECT
    ac.id,
    ac.name,
    COUNT(cds.id) AS total_datasets,
    COUNT(cds.validations_override) FILTER (WHERE cds.validations_override IS NOT NULL) AS override_count,
    ROUND(
        COUNT(cds.validations_override) FILTER (WHERE cds.validations_override IS NOT NULL)::numeric /
        NULLIF(COUNT(cds.id), 0) * 100,
        2
    ) AS override_percentage
FROM api_auto_cases ac
LEFT JOIN case_data_sets cds ON cds.case_id = ac.id
GROUP BY ac.id, ac.name
HAVING COUNT(cds.id) > 0
ORDER BY ac.id DESC;

-- 40. 查找重复的测试用例名称
SELECT
    name,
    COUNT(*) AS count,
    STRING_AGG(id::text, ', ') AS case_ids
FROM api_auto_cases
GROUP BY name
HAVING COUNT(*) > 1;

-- ====================================================================
-- 🎯 高级查询
-- ====================================================================

-- 41. 生成测试用例执行命令
SELECT
    ac.id,
    ac.name,
    'python run.py --env ' ||
    COALESCE(cds.environments[1], 'uat') ||
    ' --id ' || ac.id AS run_command
FROM api_auto_cases ac
LEFT JOIN case_data_sets cds ON cds.case_id = ac.id
WHERE ac.id = 100
LIMIT 1;

-- 42. 查找包含特定 API 路径的测试用例
SELECT
    id,
    name,
    parameters->'steps'->0->'path' AS api_path
FROM api_auto_cases
WHERE parameters::text LIKE '%/exchange/v1/public%'
ORDER BY id;

-- 43. 分析测试用例复杂度（步骤数）
SELECT
    id,
    name,
    jsonb_array_length(parameters->'steps') AS step_count,
    CASE
        WHEN jsonb_array_length(parameters->'steps') = 1 THEN 'Simple'
        WHEN jsonb_array_length(parameters->'steps') <= 3 THEN 'Medium'
        ELSE 'Complex'
    END AS complexity
FROM api_auto_cases
ORDER BY step_count DESC;

-- 44. 导出测试用例为 JSON
SELECT jsonb_pretty(jsonb_build_object(
    'case_id', ac.id,
    'name', ac.name,
    'service', ac.service,
    'parameters', ac.parameters,
    'datasets', (
        SELECT jsonb_agg(jsonb_build_object(
            'id', cds.id,
            'name', cds.data_set_name,
            'variables', cds.variables,
            'environments', cds.environments
        ))
        FROM case_data_sets cds
        WHERE cds.case_id = ac.id
    )
)) AS export_json
FROM api_auto_cases ac
WHERE ac.id = 100;

-- ====================================================================
-- 📊 统计报表
-- ====================================================================

-- 45. 按服务统计测试用例分布
SELECT
    service,
    COUNT(*) AS case_count,
    STRING_AGG(DISTINCT module, ', ') AS modules,
    SUM(jsonb_array_length(parameters->'steps')) AS total_steps
FROM api_auto_cases
GROUP BY service
ORDER BY case_count DESC;

-- 46. 按环境统计数据集分布
SELECT
    UNNEST(environments) AS environment,
    COUNT(*) AS dataset_count
FROM case_data_sets
WHERE is_active = true
GROUP BY environment
ORDER BY dataset_count DESC;

-- 47. 按标签统计
SELECT
    UNNEST(tags) AS tag,
    COUNT(*) AS usage_count
FROM api_auto_cases
GROUP BY tag
ORDER BY usage_count DESC;

-- 48. 月度测试用例创建趋势
SELECT
    DATE_TRUNC('month', created_at) AS month,
    COUNT(*) AS cases_created,
    STRING_AGG(DISTINCT service, ', ') AS services
FROM api_auto_cases
WHERE created_at >= NOW() - INTERVAL '6 months'
GROUP BY month
ORDER BY month DESC;

-- ====================================================================
-- 🛠️ 实用工具
-- ====================================================================

-- 49. 美化显示 JSONB 数据
SELECT
    id,
    name,
    jsonb_pretty(parameters) AS formatted_parameters
FROM api_auto_cases
WHERE id = 100;

-- 50. 验证 JSONB 结构完整性
SELECT
    id,
    name,
    (parameters ? 'steps') AS has_steps,
    (parameters->'steps'->0 ? 'order') AS has_order,
    (parameters->'steps'->0 ? 'path') AS has_path,
    (parameters->'steps'->0 ? 'method') AS has_method,
    (parameters->'steps'->0 ? 'request') AS has_request,
    (parameters->'steps'->0 ? 'validations') AS has_validations
FROM api_auto_cases
WHERE id = 100;

-- ====================================================================
-- 📝 使用说明
-- ====================================================================
--
-- 1. 直接执行整个文件查看所有查询示例：
--    \i database/quick_reference.sql
--
-- 2. 复制需要的查询并修改参数
--
-- 3. 带 【修改】 标记的地方需要替换为实际值
--
-- 4. 带 【填入】 标记的地方需要填入具体数值
--
-- ====================================================================
