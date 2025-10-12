# core/logger_config.py

import os
import sys
from pathlib import Path
from loguru import logger

# 移除默认的 handler
logger.remove()

# 获取日志目录
LOG_DIR = Path(__file__).parent.parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

# 获取日志级别 (从环境变量或默认为 INFO)
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

# ============================================================
# 1. 控制台输出配置 (彩色、简洁)
# ============================================================
logger.add(
    sys.stdout,
    level=LOG_LEVEL,
    format="<green>{time:HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan> - <level>{message}</level>",
    colorize=True,
    backtrace=True,
    diagnose=True
)

# ============================================================
# 2. 普通日志文件 (INFO 及以上)
# ============================================================
logger.add(
    LOG_DIR / "framework_{time:YYYY-MM-DD}.log",
    level="INFO",
    format="{time:YYYY-MM-DD HH:mm:ss.SSS} | {level: <8} | {name}:{function}:{line} - {message}",
    rotation="00:00",  # 每天午夜轮转
    retention="30 days",  # 保留 30 天
    compression="zip",  # 压缩旧日志
    encoding="utf-8",
    enqueue=True,  # 异步写入,线程安全
    backtrace=True,
    diagnose=True
)

# ============================================================
# 3. 错误日志文件 (ERROR 及以上)
# ============================================================
logger.add(
    LOG_DIR / "errors_{time:YYYY-MM-DD}.log",
    level="ERROR",
    format="{time:YYYY-MM-DD HH:mm:ss.SSS} | {level: <8} | {name}:{function}:{line} - {message}\n{extra}",
    rotation="00:00",
    retention="90 days",  # 错误日志保留更久
    compression="zip",
    encoding="utf-8",
    enqueue=True,
    backtrace=True,
    diagnose=True
)

# ============================================================
# 4. DEBUG 日志文件 (仅在 debug 模式下启用)
# ============================================================
if LOG_LEVEL == "DEBUG":
    logger.add(
        LOG_DIR / "debug_{time:YYYY-MM-DD_HH-mm-ss}.log",
        level="DEBUG",
        format="{time:YYYY-MM-DD HH:mm:ss.SSS} | {level: <8} | {process.name}:{thread.name} | {name}:{function}:{line} - {message}",
        rotation="100 MB",  # 按大小轮转
        retention="7 days",
        compression="zip",
        encoding="utf-8",
        enqueue=True,
        backtrace=True,
        diagnose=True
    )

# ============================================================
# 导出配置好的 logger
# ============================================================
__all__ = ["logger"]
