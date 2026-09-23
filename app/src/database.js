import { readFileSync } from "node:fs";
import { GetSecretValueCommand, SecretsManagerClient } from "@aws-sdk/client-secrets-manager";
import sql from "mssql";

const databaseName = "WebApi";
const rdsCertificateBundle = readFileSync(new URL("../certs/global-bundle.pem", import.meta.url), "utf8");

let poolPromise;

async function readCredentials() {
  const secretArn = process.env.DB_SECRET_ARN;
  if (!secretArn) {
    return { user: process.env.DB_USER, password: process.env.DB_PASSWORD };
  }

  const client = new SecretsManagerClient({});
  try {
    const { SecretString } = await client.send(new GetSecretValueCommand({ SecretId: secretArn }));
    const { username, password } = JSON.parse(SecretString);
    return { user: username, password };
  } finally {
    client.destroy();
  }
}

async function connectionConfig() {
  const { user, password } = await readCredentials();
  const trustServerCertificate = process.env.DB_TRUST_SERVER_CERTIFICATE === "true";

  return {
    server: process.env.DB_HOST,
    port: Number(process.env.DB_PORT ?? 1433),
    user,
    password,
    pool: { max: 5, min: 0, idleTimeoutMillis: 30_000 },
    options: {
      encrypt: true,
      trustServerCertificate,
      ...(trustServerCertificate ? {} : { cryptoCredentialsDetails: { ca: rdsCertificateBundle } }),
    },
  };
}

async function databaseExists(master) {
  const { recordset } = await master.request().query(`SELECT DB_ID(N'${databaseName}') AS id`);
  return recordset[0].id !== null;
}

async function usersTableExists(pool) {
  const { recordset } = await pool.request().query("SELECT OBJECT_ID(N'dbo.Users', N'U') AS id");
  return recordset[0].id !== null;
}

async function createDatabase(config) {
  const master = await new sql.ConnectionPool({ ...config, database: "master" }).connect();
  try {
    await master.request().query(`IF DB_ID(N'${databaseName}') IS NULL CREATE DATABASE [${databaseName}]`);
  } catch (error) {
    if (!(await databaseExists(master))) throw error;
  } finally {
    await master.close();
  }
}

async function createUsersTable(pool) {
  try {
    await pool.request().query(`
      IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
        CREATE TABLE dbo.Users (
          Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
          FirstName NVARCHAR(100) NOT NULL,
          Surname NVARCHAR(100) NOT NULL,
          Height DECIMAL(6, 2) NULL,
          Weight DECIMAL(6, 2) NOT NULL
        )
    `);
  } catch (error) {
    if (!(await usersTableExists(pool))) throw error;
  }
}

async function connect() {
  const config = await connectionConfig();
  await createDatabase(config);

  const pool = new sql.ConnectionPool({ ...config, database: databaseName });
  pool.on("error", (error) => console.error("SQL Server pool error", error));
  await pool.connect();
  try {
    await createUsersTable(pool);
    return pool;
  } catch (error) {
    await pool.close();
    throw error;
  }
}

function getPool() {
  poolPromise ??= connect().catch((error) => {
    poolPromise = undefined;
    throw error;
  });
  return poolPromise;
}

export async function closePool() {
  const pending = poolPromise;
  poolPromise = undefined;
  const pool = await pending?.catch(() => undefined);
  await pool?.close();
}

export async function withPool(work) {
  try {
    return await work(await getPool());
  } catch (error) {
    if (!(error instanceof sql.ConnectionError)) throw error;
    await closePool();
    return work(await getPool());
  }
}
