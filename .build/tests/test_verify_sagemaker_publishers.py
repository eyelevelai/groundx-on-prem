import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[1] / "bin/verify-sagemaker-publishers.py"
spec = importlib.util.spec_from_file_location("publishers", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PublishersTest(unittest.TestCase):
    def setUp(self):
        self.target = dict(accountId="903713046261", region="ap-northeast-2", endpoint="finite-model", variant="AllTraffic", publish=True)
        self.cfg = dict(metrics=dict(throughput=[dict(sagemaker=self.target)]))

    def test_competing_cluster_or_release_is_rejected(self):
        for owner in ("other-cluster/eyelevel/groundx", "cluster/other-namespace/groundx", "cluster/eyelevel/other-release"):
            with self.subTest(owner=owner), self.assertRaisesRegex(ValueError, "another publisher"):
                module.verify(self.cfg, "cluster/eyelevel/groundx", [(owner, self.cfg)])

    def test_same_owner_update_and_other_endpoint_are_accepted(self):
        other = dict(metrics=dict(throughput=[dict(sagemaker=dict(self.target, endpoint="different"))]))
        module.verify(self.cfg, "cluster/eyelevel/groundx", [("cluster/eyelevel/groundx", self.cfg), ("other/eyelevel/groundx", other)])

    def test_observation_only_is_not_a_publisher(self):
        other = dict(metrics=dict(throughput=[dict(sagemaker=dict(self.target, publish=False))]))
        module.verify(self.cfg, "cluster/eyelevel/groundx", [("other/eyelevel/groundx", other)])

    def test_rendered_secret_is_parsed_without_returning_other_secrets(self):
        text = 'kind: Secret\nstringData:\n  config.yaml: |\n    metrics:\n      throughput: []\n    admin:\n      apiKey: private-test-sentinel\n'
        configs = module.configurations(text)
        self.assertEqual(configs, [dict(metrics=dict(throughput=[]))])


if __name__ == "__main__":
    unittest.main()
