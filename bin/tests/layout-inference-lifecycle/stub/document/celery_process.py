import os
import time

import redis
from celery import Celery

app = Celery("document", broker=os.environ["BROKER_URL"], backend=os.environ["RESULT_URL"])
app.conf.task_default_queue = "layout_queue"
app.conf.worker_prefetch_multiplier = 1
app.conf.task_acks_late = True

_store = redis.Redis.from_url(os.environ["RESULT_URL"])


@app.task(name="document.celery_process.work")
def work(seconds):
    pod = os.environ.get("POD_NAME", "unknown")
    _store.rpush("consumed:" + pod, str(time.time()))
    time.sleep(seconds)
    _store.rpush("completed:" + pod, str(time.time()))
    return pod
