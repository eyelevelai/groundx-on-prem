import os
import sys
import time

import redis

store = redis.Redis.from_url(os.environ["RESULT_URL"])
store.rpush("init-started:" + os.environ.get("POD_NAME", "unknown"), str(time.time()))

time.sleep(int(os.environ.get("INIT_LAYOUT_SLEEP", "60")))

exit_code = os.environ.get("INIT_LAYOUT_EXIT", "")
if exit_code:
    sys.exit(int(exit_code))
