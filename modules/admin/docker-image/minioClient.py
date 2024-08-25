from minio import Minio
import os
import io

class MinioClient:
    def __init__(self):
        minio_host = os.getenv('MINIO_HOST', 'minio-service')
        minio_port = os.getenv('MINIO_PORT', '9000')
        minio_access_key = os.getenv('MINIO_ACCESS_KEY', 'ROOTNAME')
        minio_secret_key = os.getenv('MINIO_SECRET', 'CHANGEME123')
        self.client = Minio(
            f'{minio_host}:{minio_port}',
            access_key=minio_access_key,
            secret_key=minio_secret_key,
            secure=False
        )

    def make_bucket(self, bucket_name):
        try:
            self.client.make_bucket(bucket_name)
        except Exception as e:
            print(e)

    def list_buckets(self):
        res = self.client.list_buckets()
        return [bucket.name for bucket in res]

    def create_bucket(self, bucket_name):
        try:
            self.client.make_bucket(bucket_name)
            return None
        except Exception as e:
            return str(e)

    def upload_file(self, file_name, file_content, file_type, bucket_name):
        try:
            self.client.put_object(bucket_name, file_name, io.BytesIO(file_content.encode('utf-8')), len(file_content), file_type)
        except Exception as e:
            print(e)

    def list_files(self, bucket_name):
        res = self.client.list_objects(bucket_name)
        return [obj.object_name for obj in res]

    def delete_file(self, file_name, bucket_name):
        try:
            self.client.remove_object(bucket_name, file_name)
        except Exception as e:
            print(e)

    def read_file(self, file_name, bucket_name):
        try:
            obj = self.client.get_object(bucket_name, file_name)
            return obj.read().decode('utf-8')
        except Exception as e:
            print(e)
            return

    def delete_bucket(self, bucket_name):
        try:
            self.client.remove_bucket(bucket_name)
        except Exception as e:
            print(e)

    def health_check(self):
        try:
            self.client.list_buckets()
            return True
        except Exception as e:
            print(e)
            return False
