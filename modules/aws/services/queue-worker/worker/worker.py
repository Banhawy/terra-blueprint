"""Queue worker stub.

Long-polls an SQS queue, processes one message at a time and writes the
result to S3. Replace ``process()`` with real work; keep the loop.

Job safety: while a message is being processed, the instance marks itself
*protected from scale-in*, so the Auto Scaling group never terminates it
mid-job when the queue drains. Protection is cleared afterwards, making the
instance eligible for scale-in again. A message is only deleted after its
result is stored -- if processing fails, the message becomes visible again
after the visibility timeout and, after maxReceiveCount attempts, lands in
the dead-letter queue.
"""

import json
import logging
import os
import signal
import urllib.request
from contextlib import contextmanager
from datetime import datetime, timezone

import boto3

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("worker")

IMDS = "http://169.254.169.254/latest"


def process(body):
    """The actual job. Stub: echo the payload back with a timestamp."""
    return {
        "input": body,
        "processed_at": datetime.now(timezone.utc).isoformat(),
    }


def instance_id():
    """This instance's ID via IMDSv2, or None when not running on EC2."""
    try:
        token_req = urllib.request.Request(
            f"{IMDS}/api/token", method="PUT", headers={"X-aws-ec2-metadata-token-ttl-seconds": "300"}
        )
        token = urllib.request.urlopen(token_req, timeout=2).read().decode()
        id_req = urllib.request.Request(f"{IMDS}/meta-data/instance-id", headers={"X-aws-ec2-metadata-token": token})
        return urllib.request.urlopen(id_req, timeout=2).read().decode()
    except OSError:
        return None


class Worker:
    def __init__(self, queue_url, results_bucket, asg_name, instance_id, sqs=None, s3=None, autoscaling=None):
        self.queue_url = queue_url
        self.results_bucket = results_bucket
        self.asg_name = asg_name
        self.instance_id = instance_id
        self.sqs = sqs or boto3.client("sqs")
        self.s3 = s3 or boto3.client("s3")
        self.autoscaling = autoscaling or boto3.client("autoscaling")
        self.running = True

    def stop(self, *_):
        logger.info("Stop requested; finishing the current message")
        self.running = False

    def _set_protection(self, protected):
        if not (self.instance_id and self.asg_name):
            return
        try:
            self.autoscaling.set_instance_protection(
                InstanceIds=[self.instance_id],
                AutoScalingGroupName=self.asg_name,
                ProtectedFromScaleIn=protected,
            )
        except Exception:  # noqa: BLE001 - protection is best effort; never lose the job over it
            logger.exception("Could not set scale-in protection=%s", protected)

    @contextmanager
    def protected_from_scale_in(self):
        self._set_protection(True)
        try:
            yield
        finally:
            self._set_protection(False)

    def handle(self, message):
        body = json.loads(message["Body"])
        with self.protected_from_scale_in():
            result = process(body)
            self.s3.put_object(
                Bucket=self.results_bucket,
                Key=f"results/{message['MessageId']}.json",
                Body=json.dumps(result).encode(),
                ContentType="application/json",
            )
        self.sqs.delete_message(QueueUrl=self.queue_url, ReceiptHandle=message["ReceiptHandle"])
        logger.info("Processed message %s", message["MessageId"])

    def poll_once(self):
        response = self.sqs.receive_message(
            QueueUrl=self.queue_url, MaxNumberOfMessages=1, WaitTimeSeconds=20
        )
        for message in response.get("Messages", []):
            try:
                self.handle(message)
            except Exception:  # noqa: BLE001 - leave the message for retry / DLQ
                logger.exception("Failed to process message %s", message.get("MessageId"))

    def run(self):
        logger.info("Polling %s", self.queue_url)
        while self.running:
            self.poll_once()


def main():
    worker = Worker(
        queue_url=os.environ["QUEUE_URL"],
        results_bucket=os.environ["RESULTS_BUCKET"],
        asg_name=os.environ.get("ASG_NAME"),
        instance_id=instance_id(),
    )
    signal.signal(signal.SIGTERM, worker.stop)
    signal.signal(signal.SIGINT, worker.stop)
    worker.run()


if __name__ == "__main__":
    main()
