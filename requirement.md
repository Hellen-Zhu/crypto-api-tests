source venv/bin/activate

Enterprise-Grade API Automation Testing Framework
本项目是一个基于 Python 技术栈 (Pytest, Requests, SQLAlchemy) 构建的高度灵活、数据驱动的API自动化测试框架。其核心设计思想是将 “测试逻辑”、“测试流程”与“测试数据” 彻底分离,旨在提升测试用例的可维护性、复用性和扩展性,同时降低团队成员编写自动化用例的门槛。

核心功能 (Core Features)
完全数据驱动: 所有测试元素（环境、用例、步骤、参数、断言）均存储于数据库（PostgreSQL）,实现配置即测试。

分层用例管理: 通过 Service -> Module -> Component 的结构化层级,清晰地组织和管理大规模的测试用例。

强大的筛选与执行: 支持通过命令行按服务、模块、组件、标签 (tags)、Jira ID 等任意维度动态筛选和执行测试。

动作/步骤复用: 通过“共享动作”(shared_actions)机制,实现公共操作（如登录）的“一次定义,处处引用”。

高级参数化: 通过“测试模板”(api_auto_cases)与“数据集”(case_data_sets)的分离,轻松实现对同一业务流程进行多场景、多数据的覆盖测试。

验证覆盖机制: 支持在数据集中为特定场景定义独特的期望结果（validations_override）,完美覆盖API的各种成功、失败和异常路径。

统一关键字驱动断言引擎:

验证规则是一个统一的JSON对象。

通过 expectedStatusCode, body (部分匹配), containsText, notNull (JSONPath数组), notExist (JSONPath数组) 等关键字驱动断言。

兼具易用性与强大的功能性。

Jira 集成: 每个测试场景可关联到唯一的Jira ID,并在Allure报告中生成可点击链接,实现测试与项目管理的无缝追溯。

企业级报告: 深度集成Allure,为每个步骤、请求、响应、断言、变量提取生成详细、层级清晰的测试报告。

测试即服务 (TaaS): 内置 FastAPI 服务,可通过API调用来远程触发测试任务。

灵活的环境管理: 支持多套测试环境（如 dev, staging）的无缝切换。



框架进化史 (Framework Evolution)
本框架并非一蹴而就,而是遵循软件工程的迭代思想,逐步从一个简单的原型演进而来：

V1.0 - 基础奠定：多表关联模型

目标: 实现最基础的数据库驱动。

设计: 采用严格的关系型设计,将用例、步骤、断言分别存储在 test_cases, test_steps, test_assertions 三张表中。

成果: 验证了通过Pytest动态加载并执行数据库中用例的可行性。

痛点: 新增一个用例需要操作多张表,维护起来较为繁琐。

V2.0 - 体验优化：混合模式

目标: 简化用例的编写和维护。

设计: 废弃 test_assertions 和 test_step_outputs 表,将其内容作为 JSONB 字段（validations, outputs）合并到 api_actions（原test_steps）表中。

成果: 实现了“一个步骤,一条记录”,用例定义更加内聚和直观。

V3.0 - 规模化支持：引入复用机制

目标: 解决大量用例中“登录”等重复步骤的问题,遵循DRY原则。

设计: 新增 shared_actions 表作为“共享动作模板库”,并在 api_actions 中通过 shared_action_ref 字段进行引用。

成果: 极大提升了用例的可维护性,修改公共步骤只需改动一处。

V4.0 - 能力飞跃：实现高级参数化

目标: 解决“同一流程,不同数据,不同期望结果”的E2E测试难题。

设计: 引入 case_data_sets 表,将 api_auto_cases 升格为“测试模板”,而 case_data_sets 则负责提供具体的输入（variables）和期望输出（validations_override）。

成果: 框架从“用例驱动”进化为真正的“数据驱动”,能够以极低的成本实现场景的指数级覆盖。

V5.0 - 企业级完善：集成与易用性

目标: 对齐企业级流程,提升工程师的使用体验。

设计: 在 case_data_sets 中增加 jira_id 字段并集成到Allure报告；重构 AssertionEngine 使其支持统一的、关键字驱动的验证模式。

成果: 框架在可追溯性、易用性和报告清晰度上达到生产级标准,成为一套完整的测试解决方案。

最终架构 (Final Architecture)
数据库关系图 (ERD)
erDiagram
api_auto_cases {
int id PK
varchar name
varchar service
varchar module
varchar component
text[] tags
}
case_data_sets {
int id PK
int case_id FK
varchar data_set_name
jsonb variables
jsonb validations_override
varchar jira_id
}
api_actions {
int id PK
int case_id FK
int step_order
varchar shared_action_ref FK
}
shared_actions {
int id PK
varchar name UK
-- other api fields
}

    api_auto_cases ||--o{ case_data_sets : "提供数据"
    api_auto_cases ||--o{ api_actions : "定义流程"
    shared_actions ||..o{ api_actions : "被引用"


代码执行流程
触发: 运行 python run.py --service "MySvc" --tags "smoke"。

测试发现: pytest 启动,pytest_generate_tests 钩子被调用。

数据读取: db_handler.get_test_cases_by_filter 根据筛选条件,查询 case_data_sets 表,为每一个匹配的数据集生成一个独立的测试。

用例执行:

test_run_case 函数被调用,传入 case_id 和 data_set_id。

db_handler.get_case_details 根据这两个ID,获取用例模板、步骤序列、共享动作、数据集变量和覆盖验证,并将它们“拼接”成一个完整的、可执行的 case_details 对象。

步骤执行: api_client.execute_steps 接收 case_details 对象,开始循环执行步骤：

参数解析: placeholder_parser 使用数据集变量 ({{@...}}) 和上下文变量 ({{...}}) 替换步骤中的占位符。

请求发送: requests 发送API请求。

验证决策: api_client 决定使用 validations_override 还是默认的 validations。

断言执行: assertion_engine 根据决策结果,使用统一的关键字驱动模式执行断言,并将每一步结果汇报给Allure。

变量提取: 将步骤的输出存入上下文,供后续步骤使用。

报告生成: 所有测试执行完毕后,调用 allure 命令生成报告。

如何使用 (How to Use)
1. 环境准备
   安装所有依赖: pip install -r requirements.txt

配置数据库连接: 在 .env 文件中设置密码,在 configs/config.yaml 中配置数据库地址、用户名等。

初始化数据库: 执行最终版的SQL脚本,创建所有表结构。

2. 编写一个新测试 (Workflow)
   （可选）定义共享动作: 如果有公共步骤（如登录）,在 shared_actions 表中定义一个可复用的模板。

定义用例模板: 在 api_auto_cases 表中创建一条记录,定义测试流程的宏观属性（名称、所属服务、模块等）。

定义流程步骤: 在 api_actions 表中,为上一步的 case_id 定义一个或多个步骤。这些步骤可以是具体的API请求,也可以是对 shared_actions 的引用。

提供数据集: 在 case_data_sets 表中,为该 case_id 创建一个或多个数据集。每一行都是一个独立的测试场景,包含：

data_set_name: 场景的描述。

jira_id: 关联的Jira任务。

variables: 注入的输入参数。

validations_override: 该场景独特的期望结果。

3. 运行测试
   使用 run.py 脚本,并配合丰富的筛选参数来执行您想要的测试。

# 运行 "User Management" 服务下所有 P0 和 smoke 级别的测试
python run.py --env dev --service "User Management" --tags "P0,smoke"

# 只运行与 JIRA 任务 PROJ-456 关联的测试
python run.py --env dev --jira "PROJ-456"

# 运行并开启详细的成功断言日志,方便调试
python run.py --env dev --id 123

项目结构 (Project Structure)
api_test_framework/
├── api/                  # TaaS 服务 (FastAPI)
├── configs/              # 环境配置 (config.yaml)
├── core/                 # 核心逻辑 (api_client, db_handler, assertion_engine)
├── models/               # SQLAlchemy ORM 模型 (tables.py)
├── reports/              # Allure 报告目录
├── tests/                # Pytest 测试文件 (test_main.py, conftest.py)
├── utils/                # 工具类 (placeholder_parser.py)
├── .env                  # 环境变量 (数据库密码)
├── requirements.txt      # 项目依赖
└── run.py                # 命令行执行入口

未来展望 (Roadmap)
Jira双向集成: 测试结束后,自动将Allure报告链接和执行结果回写到Jira任务的评论区。

前端管理界面: 开发一个简单的Web界面,让非技术人员也能通过表单来创建和管理测试用例及数据集。

性能测试集成: 允许将某些API动作标记为性能测试点,并集成 locust 等工具进行压测。


1. 何时使用类 (Classes): 当我们需要“有状态的对象”
   当一段代码需要封装**数据（状态）和操作这些数据的行为（方法）**时，我们就使用类。一个类就像一个“蓝图”，我们可以根据它创建出多个独立的“对象”实例，每个实例都有自己的一套数据。

在我们的框架中，以下模块就是典型的例子：

api_client.py -> ApiClient 类:

它是什么角色？ 一个“测试执行官”。

它需要“记忆”什么？

self.session: 它需要维持一个 requests.Session 对象，以便在同一次测试的所有步骤中复用TCP连接和Cookies。

self.audit_trail: 它需要一个列表来记录并累积本次测试执行的所有步骤日志。

self.verbose: 它需要记住本次运行是否开启了详细日志模式。

为什么是类？ 因为每个测试用例在执行时，我们都会为它创建一个专属的 ApiClient 实例。这个实例的状态（比如audit_trail）只属于当前正在运行的这一个测试，与其他并行运行的测试完全隔离。

context_manager.py -> TestContext 类:

它是什么角色？ 一个“临时记事本”。

它需要“记忆”什么？ self.storage 字典。它的唯一目的就是在一个测试流程的多个步骤之间，存储和传递状态（比如第一步获取的token，或者第一次生成的随机用户名）。

为什么是类？ 这是最典型的需要状态的场景。函数执行完后变量就销毁了，无法“记忆”。只有类创建的对象，才能将数据从第二步带到第三步。

assertion_engine.py -> AssertionEngine 类:

它是什么角色？ 一个“质检专家”。

它需要“记忆”什么？ self.verbose。它在被创建时，就需要知道是否要打印详细日志，这个“配置”状态会影响它后续所有方法的行为。

为什么是类？ 将所有断言相关的逻辑（_dispatch_..., _assert_...）组织在一个类里，也使得代码结构更清晰，职责更内聚。

2. 何时使用函数 (Functions): 当我们需要“无状态的工具”
   当一段代码提供的只是一些**功能性的、无状态的“工具”**时，我们就直接使用函数。这些函数就像一个数学公式，你给它输入，它就给你输出，它不需要“记忆”上一次计算的结果。

在我们的框架中，这些模块就是典型的例子：

placeholder_parser.py:

它是什么角色？ 一个“文本翻译器”。

它的行为是什么？ 它的核心函数 resolve_placeholders 接收一段包含占位符的文本和一些上下文数据，然后返回一段被替换好的文本。它本身是无状态的，不存储任何数据。你调用它一千次，只要输入相同，输出就永远相同。

为什么是函数？ 对于这种纯粹的“输入->处理->输出”的工具性逻辑，使用函数是最简单、最直接的方式。

db_handler.py:

它是什么角色？ 一个“数据库档案管理员”。

它的行为是什么？ 它提供了一系列独立的、功能明确的查询操作，比如 get_case_details(case_id=7)。你调用它，它就去数据库里帮你把第7号档案拿出来。它本身不记录“我上次拿了哪个档案”。

为什么是函数？ 它提供的是一组无状态的数据访问服务。

conftest.py 和 run.py:

它们是什么角色？ “流程控制器”和“配置加载器”。

它们的行为是什么？ conftest.py 包含的是Pytest框架规定要使用的钩子函数和Fixtures。run.py 则是一个顶层的、线性的执行脚本。它们的逻辑是过程化的，而非面向对象的，因此使用函数是其最自然的结构。