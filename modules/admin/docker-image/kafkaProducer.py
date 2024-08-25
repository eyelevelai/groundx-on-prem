from confluent_kafka import Producer
import os

class KafkaProducer:
    def __init__(self):
        bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka-service:9092")
        self.producer = Producer({'bootstrap.servers': bootstrap_servers})

    def delivery_report(self, err, msg):
        """Delivery report callback to confirm message delivery or capture an error."""
        if err is not None:
            print(f"Message delivery failed: {err}")
        else:
            print(f"Message delivered to {msg.topic()} partition {msg.partition()} at offset {msg.offset()}.")

    def send_message(self, topic, key, value):
        try:
            self.producer.produce(
                topic=topic,
                key=key.encode('utf-8'),
                value=value.encode('utf-8'),
                callback=self.delivery_report
            )
            # Wait up to 10 seconds for the message to be delivered
            self.producer.flush(timeout=10)
        except Exception as e:
            print(f"Failed to send message: {e}")
            raise

    def close(self):
        # Wait for any outstanding messages to be delivered and clean up producer resources
        self.producer.flush()
        print("Producer closed.")
