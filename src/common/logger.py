# core/logger_config.py

import os
import sys
from pathlib import Path
from loguru import logger

# Remove default handler
logger.remove()

# Get log directory
LOG_DIR = Path(__file__).parent.parent.parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

# Get log level (from environment variable or default to INFO)
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

# ============================================================
# 1. Console output configuration (colorful, concise)
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
# 2. Regular log file (INFO and above)
# ============================================================
logger.add(
    LOG_DIR / "framework_{time:YYYY-MM-DD}.log",
    level="INFO",
    format="{time:YYYY-MM-DD HH:mm:ss.SSS} | {level: <8} | {name}:{function}:{line} - {message}",
    rotation="00:00",  # Rotate daily at midnight
    retention="30 days",  # Keep for 30 days
    compression="zip",  # Compress old logs
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
    format="{time:YYYY-MM-DD HH:mm:ss.SSS} | {level: <8} | {name}:{function}:{line} - {message}\n{extra}",
    rotation="00:00",
    retention="90 days",  # Keep error logs longer
    compression="zip",
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
        format="{time:YYYY-MM-DD HH:mm:ss.SSS} | {level: <8} | {process.name}:{thread.name} | {name}:{function}:{line} - {message}",
        rotation="100 MB",  # Rotate by size
        retention="7 days",
        compression="zip",
        encoding="utf-8",
        enqueue=True,
        backtrace=True,
        diagnose=True
    )

# ============================================================
# Export configured logger
# ============================================================
__all__ = ["logger"]
