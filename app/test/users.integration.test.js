import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { after, describe, test } from "node:test";
import { closePool } from "../src/database.js";
import { users } from "../src/users.js";

describe("SQL Server user store", { skip: !process.env.DB_HOST && "DB_HOST is not set" }, () => {
  after(closePool);

  test("stores a user and reads it back", async () => {
    const created = await users.create({ firstname: "Ada", surname: "Lovelace", height: 165.5, weight: 60.25 });

    assert.match(created.id, /^[0-9a-f-]{36}$/);
    assert.deepEqual(created, {
      id: created.id, firstname: "Ada", surname: "Lovelace", height: 165.5, weight: 60.25,
    });
    assert.deepEqual(await users.get(created.id), created);
  });

  test("stores a missing height as null", async () => {
    const created = await users.create({ firstname: "Grace", surname: "Hopper", height: null, weight: 70 });
    assert.equal((await users.get(created.id)).height, null);
  });

  test("returns null for an unknown user", async () => {
    assert.equal(await users.get(randomUUID()), null);
  });
});
