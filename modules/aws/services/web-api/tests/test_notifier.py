import importlib
import json
import os
import sys
from pathlib import Path
from unittest import mock

import pytest

os.environ.setdefault("AWS_DEFAULT_REGION", "eu-central-1")
os.environ.setdefault("WEBHOOK_SECRET_ARN", "arn:aws:secretsmanager:eu-central-1:111111111111:secret:test")
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "notifier"))

handler = importlib.import_module("handler")


def sns_event(message, subject=None):
    return {"Records": [{"Sns": {"Subject": subject, "Message": message}}]}


@pytest.fixture(autouse=True)
def reset_cache():
    handler._webhook_url = None
    yield
    handler._webhook_url = None


def test_formats_cloudwatch_alarm():
    message = json.dumps(
        {"AlarmName": "acme-staging-web-api-alb-5xx", "NewStateValue": "ALARM", "NewStateReason": "Threshold crossed"}
    )
    text = handler.format_message("ALARM", message)
    assert text == "🔴 acme-staging-web-api-alb-5xx is ALARM: Threshold crossed"


def test_formats_eventbridge_event():
    message = json.dumps(
        {
            "detail-type": "ECS Deployment State Change",
            "resources": ["arn:aws:ecs:eu-central-1:111111111111:service/c/s"],
            "detail": {"eventName": "SERVICE_DEPLOYMENT_FAILED"},
        }
    )
    text = handler.format_message(None, message)
    assert text.startswith("⚠️ ECS Deployment State Change")
    assert "SERVICE_DEPLOYMENT_FAILED" in text


def test_formats_plain_text():
    assert handler.format_message("Hello", "not json") == "Hello: not json"


def test_posts_each_record_to_webhook():
    with mock.patch.object(handler._secrets, "get_secret_value", return_value={"SecretString": "https://hooks.example.com/x"}), \
         mock.patch.object(handler, "_post", return_value=200) as post:
        result = handler.lambda_handler(sns_event("plain"), None)

    post.assert_called_once_with("https://hooks.example.com/x", "Notification: plain")
    assert result == {"delivered": 1}


def test_drops_notifications_while_secret_is_empty():
    with mock.patch.object(handler._secrets, "get_secret_value", return_value={"SecretString": ""}), \
         mock.patch.object(handler, "_post") as post:
        result = handler.lambda_handler(sns_event("plain"), None)

    post.assert_not_called()
    assert result == {"delivered": 0}
