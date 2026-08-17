"""CloudWatch-friendly logger for the Project A Lambda package.

This module is provided with the project. Import it from your handler.
Lambda already attaches a handler to the root logger; this module sets a
consistent formatter so INFO lines show up clearly in CloudWatch.

    from logging_helpers import log_event, logger

    def lambda_handler(event, context):
        log_event(event)
        logger.info("creating request")
"""

from __future__ import annotations

import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)
formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

if logger.handlers:
    for handler in logger.handlers:
        handler.setFormatter(formatter)
        handler.setLevel(logging.INFO)
else:
    handler = logging.StreamHandler()
    handler.setFormatter(formatter)
    handler.setLevel(logging.INFO)
    logger.addHandler(handler)


def log_event(payload, **fields):
    """Log a JSON-serialisable payload (typically the API Gateway event)."""
    body = payload if isinstance(payload, dict) and not fields else {"event": payload, **fields}
    logger.info("%s", json.dumps(body, default=str, indent=2))


def get_logger():
    return logger
