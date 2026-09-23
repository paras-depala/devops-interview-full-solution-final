import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import test from "node:test";
import serverless from "serverless-http";
import { createApp } from "../src/app.js";

function lambdaFor(store) {
  const handler = serverless(createApp(store));
  return async (method, path, body) => {
    const response = await handler({
      version: "2.0",
      rawPath: path,
      rawQueryString: "",
      headers: body === undefined ? {} : { "content-type": "application/json" },
      body: body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body),
      requestContext: { http: { method, path, sourceIp: "127.0.0.1" } },
    }, {});
    return { status: response.statusCode, headers: response.headers, body: JSON.parse(response.body) };
  };
}

function inMemoryStore() {
  const records = new Map();
  return {
    async create(user) {
      const record = { id: randomUUID(), ...user };
      records.set(record.id, record);
      return record;
    },
    async get(id) {
      return records.get(id) ?? null;
    },
  };
}

test("GET /health reports ok", async () => {
  const response = await lambdaFor(inMemoryStore())("GET", "/health");
  assert.equal(response.status, 200);
  assert.deepEqual(response.body, { status: "ok" });
});

test("creates a user and reads it back", async () => {
  const request = lambdaFor(inMemoryStore());
  const created = await request("POST", "/users", {
    firstname: " Ada ", surname: " Lovelace ", height: 165.5, weight: 60.2,
  });

  assert.equal(created.status, 201);
  assert.deepEqual(created.body, {
    id: created.body.id, firstname: "Ada", surname: "Lovelace", height: 165.5, weight: 60.2,
  });
  assert.equal(created.headers.location, `/users/${created.body.id}`);

  const fetched = await request("GET", `/users/${created.body.id}`);
  assert.equal(fetched.status, 200);
  assert.deepEqual(fetched.body, created.body);
});

test("height is optional", async () => {
  const request = lambdaFor(inMemoryStore());
  const created = await request("POST", "/users", { firstname: "Grace", surname: "Hopper", weight: 70 });

  assert.equal(created.status, 201);
  assert.equal(created.body.height, null);
});

test("rejects missing and invalid fields", async () => {
  const request = lambdaFor(inMemoryStore());

  const missing = await request("POST", "/users", { firstname: " ", height: 170 });
  assert.equal(missing.status, 400);
  assert.deepEqual(Object.keys(missing.body.errors).sort(), ["firstname", "surname", "weight"]);

  const invalid = await request("POST", "/users", {
    firstname: "Ada", surname: "Lovelace", height: -1, weight: "60",
  });
  assert.equal(invalid.status, 400);
  assert.deepEqual(Object.keys(invalid.body.errors).sort(), ["height", "weight"]);

  const tooPrecise = await request("POST", "/users", { firstname: "Ada", surname: "Lovelace", weight: 60.123 });
  assert.equal(tooPrecise.status, 400);
  assert.deepEqual(Object.keys(tooPrecise.body.errors), ["weight"]);
});

test("rejects bodies that are not JSON objects", async () => {
  const request = lambdaFor(inMemoryStore());
  assert.equal((await request("POST", "/users", "{not json")).status, 400);
  assert.equal((await request("POST", "/users", [])).status, 400);
  assert.equal((await request("POST", "/users")).status, 400);
});

test("returns 400 for a malformed ID and 404 for an unknown user or route", async () => {
  const request = lambdaFor(inMemoryStore());
  assert.equal((await request("GET", "/users/not-a-uuid")).status, 400);
  assert.equal((await request("GET", `/users/${randomUUID()}`)).status, 404);
  assert.equal((await request("GET", "/missing")).status, 404);
});

test("hides internal errors from the caller", async (t) => {
  t.mock.method(console, "error", () => {});
  const failing = {
    async create() { throw new Error("connection string with secrets"); },
    async get() { throw new Error("connection string with secrets"); },
  };
  const request = lambdaFor(failing);

  const response = await request("POST", "/users", { firstname: "Ada", surname: "Lovelace", weight: 60 });
  assert.equal(response.status, 500);
  assert.deepEqual(response.body, { message: "Internal server error" });
});
