import json
import os


base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
replicas_json_path = os.path.join(base_dir, "out", "replicas.json")

print_replicas = False
print_groups = True

replica_stats = {}
resource_stats = {}


def add_resources(key, value):
    name = value["node"]
    if name is None or name == "":
        return

    if name in resource_stats:
        resource_stats[name]["max"]["cpu"] += (
            value["resources"]["requests"]["cpu"] * value["max"]
        )
        resource_stats[name]["max"]["memory"] += (
            convert_memory_to_gb(value["resources"]["requests"]["memory"])
            * value["max"]
        )
        resource_stats[name]["min"]["cpu"] += (
            value["resources"]["requests"]["cpu"] * value["min"]
        )
        resource_stats[name]["min"]["memory"] += (
            convert_memory_to_gb(value["resources"]["requests"]["memory"])
            * value["min"]
        )
        resource_stats[name]["max_burst"]["cpu"] += (
            value["resources"]["limits"]["cpu"] * value["max"]
        )
        resource_stats[name]["max_burst"]["memory"] += (
            convert_memory_to_gb(value["resources"]["limits"]["memory"]) * value["max"]
        )
        resource_stats[name]["min_burst"]["cpu"] += (
            value["resources"]["requests"]["cpu"] * value["min"]
        )
        resource_stats[name]["min_burst"]["memory"] += (
            convert_memory_to_gb(value["resources"]["requests"]["memory"])
            * value["min"]
        )
    else:
        resource_stats[name] = {
            "max": {
                "cpu": value["resources"]["requests"]["cpu"] * value["max"],
                "memory": convert_memory_to_gb(value["resources"]["requests"]["memory"])
                * value["max"],
            },
            "min": {
                "cpu": value["resources"]["requests"]["cpu"] * value["min"],
                "memory": convert_memory_to_gb(value["resources"]["requests"]["memory"])
                * value["min"],
            },
            "max_burst": {
                "cpu": value["resources"]["limits"]["cpu"] * value["max"],
                "memory": convert_memory_to_gb(value["resources"]["limits"]["memory"])
                * value["max"],
            },
            "min_burst": {
                "cpu": value["resources"]["limits"]["cpu"] * value["min"],
                "memory": convert_memory_to_gb(value["resources"]["limits"]["memory"])
                * value["min"],
            },
        }

    if "gpu" in value["resources"]["requests"]:
        if "gpu" in resource_stats[name]["min"]:
            resource_stats[name]["min"]["gpu"] += (
                value["resources"]["requests"]["gpu"] * value["min"]
            )
        else:
            resource_stats[name]["min"]["gpu"] = (
                value["resources"]["requests"]["gpu"] * value["min"]
            )
    if "gpu" in value["resources"]["limits"]:
        if "gpu" in resource_stats[name]["max"]:
            resource_stats[name]["max"]["gpu"] += (
                value["resources"]["limits"]["gpu"] * value["max"]
            )
        else:
            resource_stats[name]["max"]["gpu"] = (
                value["resources"]["limits"]["gpu"] * value["max"]
            )


def convert_memory_to_gb(memory_string):
    if memory_string.endswith("Gi"):
        return int(memory_string[:-2])
    elif memory_string.endswith("Mi"):
        return int(memory_string[:-2]) / 1024
    else:
        raise ValueError(f"Unsupported memory format: {memory_string}")


def has_resources(value):
    return (
        "node" in value
        and "resources" in value
        and "requests" in value["resources"]
        and "cpu" in value["resources"]["requests"]
        and "memory" in value["resources"]["requests"]
    )


def parse_json(file_path):
    with open(file_path, "r") as file:
        return json.load(file)


replicas = parse_json(replicas_json_path)

for service, details in replicas.items():
    if isinstance(details, dict):
        was_set = False
        for key, value in details.items():
            if isinstance(value, dict) and "max" in value and "min" in value:
                was_set = True
                data = {
                    "min": {
                        "replicas": value["min"],
                    },
                    "max": {
                        "replicas": value["max"],
                    },
                    "node": value["node"],
                }
                if has_resources(value):
                    add_resources(f"{service}-{key}", value)
                    data["max"]["cpu"] = value["resources"]["limits"]["cpu"]
                    data["max"]["memory"] = convert_memory_to_gb(
                        value["resources"]["limits"]["memory"]
                    )
                    if "gpu" in value["resources"]["limits"]:
                        data["max"]["gpu"] = value["resources"]["limits"]["gpu"]
                    data["min"]["cpu"] = value["resources"]["requests"]["cpu"]
                    data["min"]["memory"] = convert_memory_to_gb(
                        value["resources"]["requests"]["memory"]
                    )
                    if "gpu" in value["resources"]["requests"]:
                        data["min"]["gpu"] = value["resources"]["requests"]["gpu"]
                replica_stats[f"{service}-{key}"] = data
            else:
                break

        if was_set == False and "max" in details and "min" in details:
            data = {
                "min": {
                    "replicas": details["min"],
                },
                "max": {
                    "replicas": details["max"],
                },
                "node": details["node"],
            }
            if has_resources(details):
                add_resources(service, details)
                data["max"]["cpu"] = details["resources"]["limits"]["cpu"]
                data["max"]["memory"] = convert_memory_to_gb(
                    details["resources"]["limits"]["memory"]
                )
                if "gpu" in details["resources"]["limits"]:
                    data["max"]["gpu"] = details["resources"]["limits"]["gpu"]
                data["min"]["cpu"] = details["resources"]["requests"]["cpu"]
                data["min"]["memory"] = convert_memory_to_gb(
                    details["resources"]["requests"]["memory"]
                )
                if "gpu" in details["resources"]["requests"]:
                    data["min"]["gpu"] = details["resources"]["requests"]["gpu"]
            replica_stats[service] = data

if print_replicas:
    print("\n\nReplica Statistics\n")
    for service, stats in replica_stats.items():
        res = ""
        if "cpu" in stats["min"]:
            res += f"\n    cpu = {stats['min']['cpu'] * stats['min']['replicas']}"
        if "memory" in stats["min"]:
            res += f"    memory = {stats['min']['memory'] * stats['min']['replicas']}GB"
        if "gpu" in stats["min"]:
            res += f"    gpu = {stats['min']['gpu'] * stats['min']['replicas']}"
        print(
            f"{service}\n    {stats['node']}\n    min = {stats['min']}\n    max = {stats['max']}{res}\n"
        )

if print_groups:
    print("\n\nNode Group Resource Requirements\n")
    for service, stats in resource_stats.items():
        print(f"{service}\n    min = {stats['min']}\n    max = {stats['max']}\n")
    print("\n")
