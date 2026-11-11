"""Forward SNS alert notifications to a chat webhook.

Subscribed to the service's alerts topic. Each SNS record is either a
CloudWatch alarm state change or an EventBridge event (e.g. a failed ECS
deployment); both are rendered as one line of text and POSTed as
``{"text": ...}``, which Slack incoming webhooks and most chat tools accept.

The webhook URL lives in Secrets Manager (WEBHOOK_SECRET_ARN). Until someone
puts a value in that secret the function logs and drops notifications instead
of failing, so a fresh environment does not page anyone about its own setup.
"""

import json
import logging
import os
import urllib.request

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

_secrets = boto3.client("secretsmanager")
_webhook_url = None


def _get_webhook_url():
    global _webhook_url
    if _webhook_url is None:
        try:
            value = _secrets.get_secret_value(SecretId=os.environ["WEBHOOK_SECRET_ARN"])
        except _secrets.exceptions.ResourceNotFoundException:
            return None
        _webhook_url = value.get("SecretString", "").strip() or None
    return _webhook_url


def format_message(subject, message):
    """Render one SNS message as a single line of text."""
    try:
        body = json.loads(message)
    except (TypeError, ValueError):
        return f"{subject or 'Notification'}: {message}"

    if "AlarmName" in body:  # CloudWatch alarm
        icon = {"ALARM": "🔴", "OK": "✅"}.get(body.get("NewStateValue"), "⚠️")
        return (
            f"{icon} {body['AlarmName']} is {body.get('NewStateValue', 'UNKNOWN')}: "
            f"{body.get('NewStateReason', '')}"
        )

    if "detail-type" in body:  # EventBridge event
        detail = body.get("detail", {})
        resources = ", ".join(body.get("resources", [])) or "n/a"
        reason = detail.get("reason") or detail.get("eventName") or ""
        return f"⚠️ {body['detail-type']} ({resources}) {reason}".strip()

    return f"{subject or 'Notification'}: {message}"


def _post(url, text):
    request = urllib.request.Request(
        url,
        data=json.dumps({"text": text}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=10) as response:  # noqa: S310 - URL comes from our own secret
        return response.status


def lambda_handler(event, _context):
    url = _get_webhook_url()
    records = event.get("Records", [])

    for record in records:
        sns = record.get("Sns", {})
        text = format_message(sns.get("Subject"), sns.get("Message"))
        if url is None:
            logger.warning("Webhook secret is empty; dropping notification: %s", text)
            continue
        _post(url, text)

    return {"delivered": len(records) if url else 0}
