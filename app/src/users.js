import { randomUUID } from "node:crypto";
import sql from "mssql";
import { withPool } from "./database.js";

function toUser(row) {
  return row ? { ...row, id: row.id.toLowerCase() } : null;
}

export const users = {
  create(user) {
    return withPool(async (pool) => {
      const { recordset } = await pool.request()
        .input("id", sql.UniqueIdentifier, randomUUID())
        .input("firstname", sql.NVarChar(100), user.firstname)
        .input("surname", sql.NVarChar(100), user.surname)
        .input("height", sql.Decimal(6, 2), user.height)
        .input("weight", sql.Decimal(6, 2), user.weight)
        .query(`
          INSERT INTO dbo.Users (Id, FirstName, Surname, Height, Weight)
          OUTPUT INSERTED.Id AS id, INSERTED.FirstName AS firstname, INSERTED.Surname AS surname,
            INSERTED.Height AS height, INSERTED.Weight AS weight
          VALUES (@id, @firstname, @surname, @height, @weight)
        `);
      return toUser(recordset[0]);
    });
  },

  get(id) {
    return withPool(async (pool) => {
      const { recordset } = await pool.request()
        .input("id", sql.UniqueIdentifier, id)
        .query(`
          SELECT Id AS id, FirstName AS firstname, Surname AS surname, Height AS height, Weight AS weight
          FROM dbo.Users
          WHERE Id = @id
        `);
      return toUser(recordset[0]);
    });
  },
};
