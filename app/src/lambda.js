import serverless from "serverless-http";
import { createApp } from "./app.js";
import { users } from "./users.js";

export const handler = serverless(createApp(users));
