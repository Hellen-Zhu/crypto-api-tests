# WebSocket验证规则配置指南

## 快速参考

本指南展示如何为WebSocket接口配置各种验证规则，无需修改任何代码。

---

## 验证规则类型

### 1. `body` - 精确值匹配（推荐）

**用途**: 验证响应JSON的精确字段值

**示例 1: 验证成功响应**
```json
{
  "validations": {
    "body": {
      "method": "subscribe",
      "code": 0,
      "result": {
        "instrument_name": "BTCUSD-PERP",
        "channel": "ticker"
      }
    }
  }
}
```

**示例 2: 验证错误响应**
```json
{
  "validations": {
    "body": {
      "method": "subscribe",
      "code": 40003,
      "message": "Unrecognized channel"
    }
  }
}
```

**示例 3: 使用占位符变量**
```json
{
  "validations": {
    "body": {
      "code": 0,
      "result": {
        "instrument_name": "{{@instrument}}"
      }
    }
  }
}
```

**特点**:
- ✅ 精确验证字段值
- ✅ 支持嵌套JSON结构
- ✅ 支持占位符变量 `{{@variable}}`
- ✅ 部分匹配（只验证指定字段，忽略其他字段）

---

### 2. `notNull` - 字段存在且非空验证

**用途**: 验证关键字段存在且值不为null

**示例 1: 验证多个字段存在**
```json
{
  "validations": {
    "notNull": [
      "$.id",
      "$.method",
      "$.code",
      "$.result"
    ]
  }
}
```

**示例 2: 验证嵌套字段**
```json
{
  "validations": {
    "notNull": [
      "$.result.instrument_name",
      "$.result.data[0].a",
      "$.result.data[0].h",
      "$.result.data[0].l"
    ]
  }
}
```

**JSONPath语法**:
- `$.field` - 根级字段
- `$.parent.child` - 嵌套字段
- `$.array[0]` - 数组元素
- `$.array[*]` - 数组所有元素

---

### 3. `containsText` - 文本包含验证

**用途**: 验证响应中包含特定文本（用于错误消息）

**示例 1: 验证错误消息包含关键词**
```json
{
  "validations": {
    "containsText": "Unrecognized"
  }
}
```

**示例 2: 配合body使用**
```json
{
  "validations": {
    "body": {
      "code": 40003
    },
    "containsText": "channel"
  }
}
```

---

### 4. `notExist` - 字段不存在验证

**用途**: 验证某些字段不应该出现（负面验证）

**示例 1: 验证错误响应中没有result字段**
```json
{
  "validations": {
    "body": {
      "code": 40003
    },
    "notExist": [
      "$.result"
    ]
  }
}
```

**示例 2: 验证敏感数据未泄露**
```json
{
  "validations": {
    "notExist": [
      "$.password",
      "$.secret_key",
      "$.internal_error"
    ]
  }
}
```

---

## 组合验证策略

### 策略 1: 全面验证（正面测试推荐）

```json
{
  "validations": {
    "notNull": [
      "$.id",
      "$.method",
      "$.code",
      "$.result",
      "$.result.data[0]"
    ],
    "body": {
      "method": "subscribe",
      "code": 0,
      "result": {
        "channel": "ticker",
        "instrument_name": "{{@instrument}}"
      }
    }
  }
}
```

**说明**:
- `notNull`: 确保所有关键字段都存在
- `body`: 精确验证字段值
- 适用于成功场景的严格验证

---

### 策略 2: 精简验证（负面测试推荐）

```json
{
  "validations": {
    "body": {
      "code": 40003,
      "method": "subscribe"
    }
  }
}
```

**说明**:
- 只使用`body`验证，不使用`notNull`
- 避免冗余验证
- 适用于错误场景

---

### 策略 3: 灵活验证（部分字段未知）

```json
{
  "validations": {
    "notNull": [
      "$.code",
      "$.message"
    ],
    "containsText": "error"
  }
}
```

**说明**:
- 只验证字段存在和部分内容
- 不验证精确值（当响应值动态变化时）
- 适用于错误消息格式不固定的场景

---

## 实际应用场景

### 场景 1: Ticker订阅成功

**WebSocket消息**:
```json
{
  "id": 1,
  "method": "subscribe",
  "code": 0,
  "result": {
    "instrument_name": "BTCUSD-PERP",
    "channel": "ticker",
    "data": [
      {
        "a": "50000.5",
        "h": "51000.0",
        "l": "49000.0"
      }
    ]
  }
}
```

**验证配置**:
```json
{
  "validations": {
    "notNull": [
      "$.id",
      "$.method",
      "$.code",
      "$.result.instrument_name",
      "$.result.data[0].a",
      "$.result.data[0].h",
      "$.result.data[0].l"
    ],
    "body": {
      "method": "subscribe",
      "code": 0,
      "result": {
        "instrument_name": "{{@instrument}}",
        "channel": "ticker"
      }
    }
  }
}
```

---

### 场景 2: 无效Channel订阅

**WebSocket消息**:
```json
{
  "id": 1,
  "method": "subscribe",
  "code": 40003,
  "message": "Unrecognized channel",
  "channel": "invalid_channel_name"
}
```

**验证配置**:
```json
{
  "validations": {
    "body": {
      "method": "subscribe",
      "code": 40003,
      "message": "Unrecognized channel"
    }
  }
}
```

---

### 场景 3: 无效Instrument订阅

**WebSocket消息**:
```json
{
  "id": 1,
  "method": "subscribe",
  "code": 40003,
  "message": "Invalid instrument: INVALID-SYMBOL"
}
```

**验证配置**:
```json
{
  "validations": {
    "body": {
      "method": "subscribe",
      "code": 40003
    },
    "containsText": "instrument"
  }
}
```

---

### 场景 4: Malformed消息

**WebSocket消息**:
```json
{
  "code": 40003,
  "message": "Missing required field: method"
}
```

**验证配置**:
```json
{
  "validations": {
    "body": {
      "code": 40003
    },
    "notExist": ["$.result"]
  }
}
```

---

## 使用validations_override覆盖验证规则

### 什么是validations_override？

`validations_override`允许为特定数据集覆盖默认的验证规则，无需修改测试用例本身。

### 使用场景

1. **同一接口的成功/失败场景**: 成功返回200+数据，失败返回400+错误
2. **不同参数组合的不同响应**: 不同错误参数返回不同错误码
3. **边界值测试**: 特殊边界值可能有特殊响应格式

### 示例: 覆盖步骤3的验证规则

**默认验证** (在`api_auto_cases.parameters.steps[2].validations`):
```json
{
  "notNull": ["$.id", "$.code"],
  "body": {
    "code": 0
  }
}
```

**覆盖验证** (在`case_data_sets.validations_override`):
```json
{
  "3": {
    "body": {
      "code": 40003,
      "message": "Unrecognized channel"
    }
  }
}
```

**结果**: 数据集执行时，步骤3将使用覆盖的验证规则，忽略默认验证。

---

## SQL更新示例

### 更新单个数据集

```sql
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "method": "subscribe",
      "code": 40003,
      "message": "Unrecognized channel"
    }
  }
}'::jsonb
WHERE id = 27;
```

### 更新多个数据集（相同验证规则）

```sql
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "code": 40003,
      "method": "subscribe"
    }
  }
}'::jsonb
WHERE id IN (30, 31, 32, 33);
```

### 更新多个数据集（不同验证规则）

```sql
-- Dataset 27: 完整验证
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "method": "subscribe",
      "code": 40003,
      "message": "Unrecognized channel"
    }
  }
}'::jsonb
WHERE id = 27;

-- Dataset 29: 简化验证
UPDATE case_data_sets
SET validations_override = '{
  "3": {
    "body": {
      "code": 40003,
      "method": "subscribe"
    }
  }
}'::jsonb
WHERE id = 29;
```

---

## 验证规则调试技巧

### 1. 使用debug模式查看实际响应

```bash
python run.py --env exchange_uat --id <dataset_id> --debug-mode
```

### 2. 查询数据库中的audit日志

```sql
SELECT
    ds.data_set_name,
    audit.step_order,
    audit.response_details
FROM auto_test_audit audit
JOIN auto_case_audit ac ON audit.audit_case_id = ac.id
JOIN case_data_sets ds ON ac.data_set_id = ds.id
WHERE ac.runid = '<your_run_id>'
AND audit.step_order = 3;
```

### 3. 检查Allure报告

访问 http://127.0.0.1:8889 查看:
- 请求消息内容
- 响应消息内容
- 验证失败详情
- JSONPath匹配结果

### 4. 临时简化验证规则

如果测试失败，先简化验证规则找出问题：

```json
// 从这个开始
{
  "body": {
    "method": "subscribe",
    "code": 40003,
    "message": "Unrecognized channel",
    "channel": "invalid_name"
  }
}

// 逐步简化
{
  "body": {
    "method": "subscribe",
    "code": 40003
  }
}

// 最简化
{
  "notNull": ["$.code"]
}
```

---

## 常见错误和解决方案

### 错误 1: Value mismatch at path 'body.code'

**原因**: 期望的错误码与实际返回的不匹配

**解决**:
1. 检查实际API响应的错误码
2. 更新验证规则中的code值
3. 或者只验证code存在：`"notNull": ["$.code"]`

### 错误 2: Missing key at path 'body.message'

**原因**: 响应中没有message字段，但验证规则要求验证

**解决**:
1. 检查API实际响应格式
2. 移除验证规则中的message字段
3. 或者使用`notNull`代替精确匹配

### 错误 3: Path '$.result.data[0]' not found

**原因**: 错误响应中没有result字段

**解决**:
1. 使用`validations_override`为错误场景提供不同的验证规则
2. 不要在错误场景验证result字段

---

## 最佳实践总结

### ✅ DO (推荐做法)

1. **正面测试使用组合验证**:
   ```json
   {
     "notNull": ["$.id", "$.code", "$.result"],
     "body": {"code": 0, "result": {...}}
   }
   ```

2. **负面测试使用精简验证**:
   ```json
   {
     "body": {"code": 40003, "method": "subscribe"}
   }
   ```

3. **使用validations_override区分场景**:
   - 成功场景验证完整数据结构
   - 失败场景验证错误码和错误消息

4. **验证关键业务字段**:
   - 必须存在的字段用`notNull`
   - 必须匹配的值用`body`

5. **使用占位符变量**:
   ```json
   {
     "body": {
       "result": {
         "instrument_name": "{{@instrument}}"
       }
     }
   }
   ```

### ❌ DON'T (避免做法)

1. **不要过度验证**:
   ```json
   // 不推荐：验证所有字段
   {
     "body": {
       "id": 1,
       "method": "subscribe",
       "code": 0,
       "result": {...},
       "timestamp": 1234567890,
       "server_version": "1.0.0"
     }
   }
   ```

2. **不要在负面测试中使用notNull**:
   ```json
   // 不推荐：冗余验证
   {
     "notNull": ["$.code"],
     "body": {"code": 40003}
   }

   // 推荐：只用body
   {
     "body": {"code": 40003}
   }
   ```

3. **不要验证动态值**:
   ```json
   // 不推荐：timestamp每次都不同
   {
     "body": {
       "timestamp": 1234567890
     }
   }

   // 推荐：只验证存在
   {
     "notNull": ["$.timestamp"]
   }
   ```

4. **不要混用默认验证和override**:
   - 如果使用override，确保完整替换默认验证
   - override会完全替换默认验证，不会合并

---

## 参考资源

- **框架文档**: [CLAUDE.md](../../CLAUDE.md)
- **WebSocket实现**: [WEBSOCKET_IMPLEMENTATION_SUMMARY.md](../../WEBSOCKET_IMPLEMENTATION_SUMMARY.md)
- **验证引擎代码**: [core/assertion_engine.py](../../core/assertion_engine.py)
- **JSONPath文档**: https://goessner.net/articles/JsonPath/

---

**文档版本**: v1.0
**更新时间**: 2025-10-13
**适用框架版本**: WebSocket MVP v1.0
