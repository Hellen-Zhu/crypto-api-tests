# core/logger_config.py

import os
import sys
from pathlib import Path
from loguru import logger

# Remove default handler
logger.remove()

# ============================================================
# Configuration from Environment Variables
# ============================================================
# All configurations are loaded from .env file with sensible defaults

# Log directory
LOG_DIR_PATH = os.getenv("LOG_DIR", "logs")
LOG_DIR = Path(__file__).parent.parent.parent / LOG_DIR_PATH
LOG_DIR.mkdir(exist_ok=True)

# Log level
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

# Rotation settings
LOG_ROTATION_TIME = os.getenv("LOG_ROTATION_TIME", "00:00")
LOG_ROTATION_SIZE = os.getenv("LOG_ROTATION_SIZE", "100 MB")

# Retention periods
LOG_RETENTION_GENERAL = os.getenv("LOG_RETENTION_GENERAL", "30 days")
LOG_RETENTION_ERROR = os.getenv("LOG_RETENTION_ERROR", "90 days")
LOG_RETENTION_DEBUG = os.getenv("LOG_RETENTION_DEBUG", "7 days")

# Compression format
LOG_COMPRESSION = os.getenv("LOG_COMPRESSION", "zip")

# Log formats (with defaults matching current setup)
LOG_CONSOLE_FORMAT = os.getenv(
    "LOG_CONSOLE_FORMAT",
    "<green>{time:HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan> - <level>{message}</level>"
)
LOG_FILE_FORMAT = os.getenv(
    "LOG_FILE_FORMAT",
    "{time:YYYY-MM-DD HH:mm:ss.SSS} | {level: <8} | {name}:{function}:{line} - {message}"
)
LOG_ERROR_FORMAT = os.getenv(
    "LOG_ERROR_FORMAT",
    "{time:YYYY-MM-DD HH:mm:ss.SSS} | {level: <8} | {name}:{function}:{line} - {message}\n{extra}"
)
LOG_DEBUG_FORMAT = os.getenv(
    "LOG_DEBUG_FORMAT",
    "{time:YYYY-MM-DD HH:mm:ss.SSS} | {level: <8} | {process.name}:{thread.name} | {name}:{function}:{line} - {message}"
)

# ============================================================
# 1. Console output configuration (colorful, concise)
# ============================================================
logger.add(
    sys.stdout,
    level=LOG_LEVEL,
    format=LOG_CONSOLE_FORMAT,
    colorize=True,
    backtrace=True,
    diagnose=True
)

# ============================================================
# 2. Regular log file (INFO and above)
# ============================================================
logger.add(
    LOG_DIR / "framework_{time:YYYY-MM-DD}.log",
    level="INFO",
    format=LOG_FILE_FORMAT,
    rotation=LOG_ROTATION_TIME,  # From .env, default: "00:00" (daily at midnight)
    retention=LOG_RETENTION_GENERAL,  # From .env, default: "30 days"
    compression=LOG_COMPRESSION,  # From .env, default: "zip"
    encoding="utf-8",
    enqueue=True,  # Asynchronous write, thread-safe
    backtrace=True,
    diagnose=True
)

# ============================================================
# 3. Error log file (ERROR and above)
# ============================================================
logger.add(
    LOG_DIR / "errors_{time:YYYY-MM-DD}.log",
    level="ERROR",
    format=LOG_ERROR_FORMAT,
    rotation=LOG_ROTATION_TIME,  # From .env, default: "00:00"
    retention=LOG_RETENTION_ERROR,  # From .env, default: "90 days" (keep errors longer)
    compression=LOG_COMPRESSION,  # From .env, default: "zip"
    encoding="utf-8",
    enqueue=True,
    backtrace=True,
    diagnose=True
)

# ============================================================
# 4. DEBUG log file (enabled only in debug mode)
# ============================================================
if LOG_LEVEL == "DEBUG":
    logger.add(
        LOG_DIR / "debug_{time:YYYY-MM-DD_HH-mm-ss}.log",
        level="DEBUG",
        format=LOG_DEBUG_FORMAT,
        rotation=LOG_ROTATION_SIZE,  # From .env, default: "100 MB" (rotate by size for debug)
        retention=LOG_RETENTION_DEBUG,  # From .env, default: "7 days"
        compression=LOG_COMPRESSION,  # From .env, default: "zip"
        encoding="utf-8",
        enqueue=True,
        backtrace=True,
        diagnose=True
    )

# ============================================================
# Export configured logger
# ============================================================
__all__ = ["logger"]
