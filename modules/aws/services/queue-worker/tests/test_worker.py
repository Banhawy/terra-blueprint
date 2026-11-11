import importlib
import json
import os
import sys
from pathlib import Path
from unittest import mock

os.environ.setdefault("AWS_DEFAULT_REGION", "eu-central-1")
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "worker"))

worker_module = importlib.import_module("worker")


def make_worker(**overrides):
    clients = {"sqs": mock.Mock(), "s3": mock.Mock(), "autoscaling": mock.Mock()}
    clients.update(overrides)
    w = worker_module.Worker(
        queue_url="https://sqs.example/queue",
        results_bucket="results",
        asg_name="acme-staging-queue-worker",
        instance_id="i-0123456789abcdef0",
        **clients,
    )
    return w, clients


MESSAGE = {"MessageId": "m-1", "ReceiptHandle": "rh-1", "Body": json.dumps({"job": 42})}


def test_processes_stores_result_and_deletes_message():
    w, c = make_worker()

    w.handle(MESSAGE)

    put = c["s3"].put_object.call_args.kwargs
    assert put["Bucket"] == "results"
    assert put["Key"] == "results/m-1.json"
    assert json.loads(put["Body"])["input"] == {"job": 42}
    c["sqs"].delete_message.assert_called_once_with(QueueUrl="https://sqs.example/queue", ReceiptHandle="rh-1")


def test_protects_instance_during_job_and_releases_after():
    w, c = make_worker()

    w.handle(MESSAGE)

    calls = [call.kwargs["ProtectedFromScaleIn"] for call in c["autoscaling"].set_instance_protection.call_args_list]
    assert calls == [True, False]


def test_failed_job_keeps_message_and_releases_protection():
    w, c = make_worker()
    c["s3"].put_object.side_effect = RuntimeError("S3 down")
    c["sqs"].receive_message.return_value = {"Messages": [MESSAGE]}

    w.poll_once()  # must not raise

    c["sqs"].delete_message.assert_not_called()
    assert c["autoscaling"].set_instance_protection.call_args.kwargs["ProtectedFromScaleIn"] is False


def test_protection_failure_does_not_lose_the_job():
    w, c = make_worker()
    c["autoscaling"].set_instance_protection.side_effect = RuntimeError("throttled")

    w.handle(MESSAGE)

    c["sqs"].delete_message.assert_called_once()


def test_skips_protection_off_ec2():
    w, c = make_worker()
    w.instance_id = None

    w.handle(MESSAGE)

    c["autoscaling"].set_instance_protection.assert_not_called()


def test_stop_ends_run_loop():
    w, c = make_worker()
    c["sqs"].receive_message.side_effect = lambda **_: (w.stop(), {"Messages": []})[1]

    w.run()

    assert c["sqs"].receive_message.call_count == 1
