from confluent_kafka.admin import AdminClient, NewTopic
from confluent_kafka import KafkaException
import os

class KafkaAdmin:
    def __init__(self):
        # Use the Kubernetes service name and port for the Kafka cluster
        bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka-service:9092")
        self.admin_client = AdminClient({'bootstrap.servers': bootstrap_servers})


    def create_topic(self, topic_name, num_partitions=1, replication_factor=1):
        topic_list = [NewTopic(topic=topic_name, num_partitions=num_partitions, replication_factor=replication_factor)]
        fs = self.admin_client.create_topics(topic_list)
        for topic, f in fs.items():
            try:
                f.result()  # The result itself is None
                print(f"Topic '{topic_name}' created successfully.")
            except KafkaException as e:
                if e.args[0].code() == KafkaError.TOPIC_ALREADY_EXISTS:
                    print(f"Topic '{topic_name}' already exists.")
                else:
                    print(f"Failed to create topic '{topic_name}': {e}")

    def delete_topic(self, topic_name):
        fs = self.admin_client.delete_topics([topic_name])
        for topic, f in fs.items():
            try:
                f.result()  # The result itself is None
                print(f"Topic '{topic_name}' deleted successfully.")
            except KafkaException as e:
                print(f"Failed to delete topic '{topic_name}': {e}")

    def list_topics(self):
        metadata = self.admin_client.list_topics(timeout=10)
        return [i for i in list(metadata.topics.keys()) if not i.startswith("__")]

    def describe_topic(self, topic_name):
        metadata = self.admin_client.list_topics(timeout=10)
        if topic_name in metadata.topics:
            topic_metadata = metadata.topics[topic_name]
            return {
                'topic': topic_metadata.topic,
                'partitions': len(topic_metadata.partitions),
                'replicas': [p.replicas for p in topic_metadata.partitions.values()],
            }
        else:
            return f"Topic '{topic_name}' does not exist."

    def health_check(self):
        try:
            metadata = self.admin_client.list_topics(timeout=10)
            if metadata.topics:
                print("Kafka cluster is healthy.")
                return True, None
            else:
                print("Kafka cluster is accessible but no topics found.")
                return True, None
        except KafkaException as e:
            print(f"Kafka health check failed: {e}")
            return False, e
