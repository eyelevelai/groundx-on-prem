from confluent_kafka import Consumer, KafkaException, KafkaError
import os

class KafkaConsumer:
    def __init__(self, topic, group_id=None, auto_offset_reset='earliest'):
        bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
        self.consumer = Consumer({
            'bootstrap.servers': bootstrap_servers,
            'group.id': group_id or 'default-group',
            'auto.offset.reset': auto_offset_reset,
            'enable.auto.commit': True
        })
        self.consumer.subscribe([topic])
        print(f"Subscribed to topic: {topic}")

    def consume_messages(self):
        res = []
        try:
            while True:
                msg = self.consumer.poll(timeout=5.0)  # Increase timeout for polling
                if msg is None:
                    print("No message received in this poll interval.")
                    continue  # No message, continue polling
                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        # End of partition event
                        print(f"Reached end of partition for {msg.topic()} at offset {msg.offset()}.")
                    else:
                        # Other errors
                        raise KafkaException(msg.error())
                else:
                    message_value = msg.value().decode('utf-8')
                    print(f"Consumed message: {message_value} from topic {msg.topic()} partition {msg.partition()} offset {msg.offset()}")
                    res.append(message_value)
        except KafkaException as e:
            print(f"Error occurred: {e}")
        finally:
            print("Final consumed messages:", res)
            return res

    def close(self):
        self.consumer.close()
        print("Consumer closed.")
