# 0007. Queue workers protect themselves from scale-in while busy

- Status: accepted

## Context

An Auto Scaling group that scales on queue depth removes instances when the
queue drains, and it does not know which instances are mid-job. A terminated
worker loses its job's progress. The message becomes visible again and the job
reruns from scratch.

Another pattern is for the worker to *detach* itself from the group, process one
job and terminate. It is safe, but every job then needs a fresh instance, and
the group's capacity accounting becomes hard to follow.

## Decision

- Workers are long-lived processes that take one message at a time.
- Before processing, the worker sets **scale-in protection** on its own instance
  (`autoscaling:SetInstanceProtection`) and clears it when done. The ASG only
  terminates unprotected (idle) instances.
- Instance refresh uses `scale_in_protected_instances = "Wait"`, so code
  rollouts wait for busy workers too.
- systemd stops the worker with SIGTERM and `TimeoutStopSec` = the job timeout,
  so it finishes the current message before exiting.
- A message is deleted only after its result is written (at-least-once). After
  `max_receive_count` failed attempts it moves to the dead-letter queue, which
  raises an alarm.

## Consequences

- Jobs must be idempotent: a crash after the result is written but before the
  delete runs the job again.
- If the worker crashes while protected, the protection stays until the instance
  is replaced. Instance refresh or a manual termination clears it.
- `job_timeout_seconds` must exceed the longest job. It is both the visibility
  timeout and the graceful-stop timeout.
