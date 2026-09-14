// Run through node stdin inside the disposable app's middleware container.
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { loadEnv } from "/workspace/middleware/dist/config/env.js";
import { MySqlAppRepository } from "/workspace/middleware/dist/db/mysqlRepository.js";
import { createManagedDataAdapters, redisKey } from "/workspace/middleware/dist/managedData.js";

const mode = process.argv[2];
assert.ok(["write", "read", "delete", "isolation"].includes(mode));
let stage = "configuration";
const deadline = setTimeout(() => {
  console.error("Application storage check timed out");
  process.exit(1);
}, 30_000);

try {
  const env = loadEnv();
  assert.equal(env.GROUNDX_DEPLOY_ENVIRONMENT, "dev");
  assert.equal(env.OBJECT_PREFIX, "projects/373cdb9b5bcf/dev/");
  assert.equal(env.REDIS_PREFIX, "{373cdb9b5bcf_dev}");
  assert.equal(new URL(env.DATABASE_URL).pathname, "/gx-892ba7db-542f-4da6-bdd1-6acaa10b-373cdb9b5bcf-dev");
  const repository = new MySqlAppRepository(env);
  const adapters = createManagedDataAdapters(env);
  assert.ok(adapters.objects && adapters.cache);
  const id = "age344-lifecycle-20260914";
  const value = "age344-persisted-test-value";
  const objectKey = `${env.OBJECT_PREFIX}__age344_lifecycle/${id}`;
  const cacheKey = redisKey(env.REDIS_PREFIX, id);

  if (mode === "write") {
    stage = "records write";
    const existing = await repository.readManagedDataReadinessProbe(id);
    if (existing === null) await repository.writeManagedDataReadinessProbe(id, value);
    else assert.equal(existing, value);
    stage = "objects write";
    await adapters.objects.put(objectKey, value);
    stage = "cache write";
    await adapters.cache.set(cacheKey, value, 3600);
  }
  if (mode === "write" || mode === "read" || mode === "isolation") {
    stage = "records read";
    assert.equal(await repository.readManagedDataReadinessProbe(id), value);
    stage = "objects read";
    assert.equal(await adapters.objects.get(objectKey), value);
    stage = "cache read";
    assert.equal(await adapters.cache.get(cacheKey), value);
  }
  if (mode === "delete") {
    stage = "cleanup";
    await repository.deleteManagedDataReadinessProbe(id);
    await adapters.objects.delete(objectKey);
    await adapters.cache.delete(cacheKey);
    assert.equal(await repository.readManagedDataReadinessProbe(id), null);
    assert.equal(await adapters.cache.get(cacheKey), null);
  }
  if (mode === "isolation") {
    stage = "records isolation";
    const mysql = createRequire("/workspace/package.json")("mysql2/promise");
    const connection = await mysql.createConnection(env.DATABASE_URL);
    try {
      await assert.rejects(connection.query("SELECT User FROM mysql.user LIMIT 1"),
        error => error.code === "ER_TABLEACCESS_DENIED_ERROR");
    } finally {
      await connection.end();
    }
    stage = "objects isolation";
    await assert.rejects(
      adapters.objects.put(`projects/age344-isolation-probe/dev/${id}`, value),
      error => error.name === "AccessDenied",
    );
    stage = "cache isolation";
    await assert.rejects(
      adapters.cache.set(`{age344_isolation_probe}:${id}`, value, 60),
      error => String(error.message).includes("NOPERM"),
    );
  }
  console.log(JSON.stringify({ mode, records: "passed", objects: "passed", cache: "passed" }));
  clearTimeout(deadline);
  process.exit(0);
} catch {
  console.error(JSON.stringify({ failedStage: stage }));
  clearTimeout(deadline);
  process.exit(1);
}
