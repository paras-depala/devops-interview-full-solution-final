import { createApp } from "./app.js";
import { users } from "./users.js";

const port = Number(process.env.PORT ?? 3000);

createApp(users).listen(port, "127.0.0.1", () => {
  console.log(`Listening on http://127.0.0.1:${port}`);
});
