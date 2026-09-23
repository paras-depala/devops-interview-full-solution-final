import express from "express";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isName(value) {
  return typeof value === "string" && value.trim().length > 0 && value.trim().length <= 100;
}

function isMeasurement(value) {
  return Number.isFinite(value) && value > 0 && value < 10_000 && Math.round(value * 100) / 100 === value;
}

function validateUser(body) {
  const errors = {};
  if (!isName(body.firstname)) errors.firstname = "Required, up to 100 characters";
  if (!isName(body.surname)) errors.surname = "Required, up to 100 characters";
  if (!isMeasurement(body.weight)) errors.weight = "Required, kilograms above 0 with up to 2 decimal places";
  if (body.height != null && !isMeasurement(body.height)) {
    errors.height = "Optional, centimetres above 0 with up to 2 decimal places";
  }
  return errors;
}

export function createApp(userStore) {
  const app = express();
  app.use(express.json());

  app.get("/health", (_request, response) => {
    response.json({ status: "ok" });
  });

  app.post("/users", async (request, response) => {
    const body = request.body;
    if (typeof body !== "object" || body === null || Array.isArray(body)) {
      response.status(400).json({ message: "Request body must be a JSON object" });
      return;
    }

    const errors = validateUser(body);
    if (Object.keys(errors).length > 0) {
      response.status(400).json({ message: "Invalid user", errors });
      return;
    }

    const user = await userStore.create({
      firstname: body.firstname.trim(),
      surname: body.surname.trim(),
      height: body.height ?? null,
      weight: body.weight,
    });
    response.status(201).location(`/users/${user.id}`).json(user);
  });

  app.get("/users/:id", async (request, response) => {
    if (!uuidPattern.test(request.params.id)) {
      response.status(400).json({ message: "Invalid user ID" });
      return;
    }

    const user = await userStore.get(request.params.id);
    if (!user) {
      response.status(404).json({ message: "User not found" });
      return;
    }
    response.json(user);
  });

  app.use((_request, response) => {
    response.status(404).json({ message: "Not found" });
  });

  app.use((error, _request, response, _next) => {
    if (error.status >= 400 && error.status < 500) {
      response.status(error.status).json({ message: "Invalid request body" });
      return;
    }
    console.error(error);
    response.status(500).json({ message: "Internal server error" });
  });

  return app;
}
