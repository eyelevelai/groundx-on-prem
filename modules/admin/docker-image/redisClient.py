import redis
import os

class RedisClient:
    def __init__(self):
        redis_host = os.getenv('REDIS_HOST', 'localhost')
        redis_port = os.getenv('REDIS_PORT', '6379')
        self.client = redis.StrictRedis(host=redis_host, port=int(redis_port))

    def set(self, key, value):
        self.client.set(key, value)

    def get(self, key):
        try:
            return self.client.get(key).decode('utf-8') # type: ignore
        except AttributeError:
            return None

    def delete(self, key):
        self.client.delete(key)

    def list_keys(self):
        return [key.decode('utf-8') for key in self.client.keys()]

    def health_check(self):
        try:
            # PING command returns True if the Redis server is up and running
            return True, self.client.ping()
        except redis.exceptions.ConnectionError as e:
            return False, str(e)
