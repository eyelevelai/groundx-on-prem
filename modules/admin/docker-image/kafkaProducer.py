from confluent_kafka import Producer
import socket
import os

class KafkaProducer:
    def __init__(self, topic):
        self.conf = {
            'bootstrap.servers': os.getenv("KAFKA_HOST", "localhost:9092"),
            'client.id': socket.gethostname()
        }
        self.producer = Producer(self.conf)
        self.topic = topic

    def acked(self, err, msg):
        if err is not None:
            print("Failed to deliver message: %s: %s" % (str(msg), str(err)))
        else:
            print("Message produced: %s" % (str(msg)))

    def produce_message(self, key, value):
        self.producer.produce(self.topic, key=key, value=value, callback=self.acked)
        self.producer.poll(1)  # Serve delivery reports (callbacks)

    def flush(self):
        self.producer.flush()
