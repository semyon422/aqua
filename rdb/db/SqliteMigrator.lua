local class = require("class")

---@class rdb.SqliteMigrator
---@operator call: rdb.SqliteMigrator
local SqliteMigrator = class()

---@param db rdb.SqliteDatabase
function SqliteMigrator:new(db)
	self.db = db
end

---@param new_ver integer
---@param migrations {[integer]: string|fun(self: rdb.IDatabase)}
---@return integer
function SqliteMigrator:migrate(new_ver, migrations)
	local db = self.db

	local ver = db:user_version()

	for i = ver + 1, new_ver do
		db:exec("BEGIN")
		local migration = migrations[i]
		if type(migration) == "string" then
			db:exec(migration)
		elseif type(migration) == "function" then
			migration(db)
		end
		db:user_version(i)
		db:exec("COMMIT")
	end

	return new_ver - ver
end

return SqliteMigrator
