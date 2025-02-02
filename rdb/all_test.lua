local LjsqliteDatabase = require("rdb.LjsqliteDatabase")
local TableOrm = require("rdb.TableOrm")
local Models = require("rdb.Models")
local sql_util = require("rdb.sql_util")
local table_util = require("table_util")

local users = {}

users.table_name = "users"

users.create_query = [[
CREATE TABLE IF NOT EXISTS "users" (
	"id" INTEGER NOT NULL PRIMARY KEY,
	"name" TEXT NOT NULL UNIQUE,
	"is_admin" INTEGER NOT NULL DEFAULT 0,
	"null_flag" INTEGER DEFAULT NULL,
	"nullable_flag" INTEGER DEFAULT 1,
	"role" INTEGER DEFAULT 0
);
]]

local Roles = {
	user = 0,
	admin = 1,
}

users.types = {
	is_admin = "boolean",
	role = {
		decode = function(v) return table_util.keyof(Roles, v) end,
		encode = function(k) return Roles[k] end,
	}
}

users.relations = {
	posts = {has_many = "posts", key = "user_id"},
}

local posts = {}

posts.table_name = "posts"

posts.create_query = [[
CREATE TABLE IF NOT EXISTS "posts" (
	"id" INTEGER NOT NULL PRIMARY KEY,
	"user_id" INTEGER NOT NULL,
	"text" TEXT NOT NULL DEFAULT "",
	FOREIGN KEY (user_id) references users(id) ON DELETE CASCADE
);
]]

posts.relations = {
	user = {belongs_to = "users", key = "user_id"},
}

local migrations = {
	[1] = "ALTER TABLE users ADD added_column INTEGER NOT NULL DEFAULT 0;",
}

local test = {}

function test.all(t)
	local db = LjsqliteDatabase()
	db:open(":memory:")

	db:exec(users.create_query)
	db:exec(posts.create_query)
	db:exec("PRAGMA foreign_keys = ON;")

	local _models = {
		users = users,
		posts = posts,
	}
	local orm = TableOrm(db)

	assert(orm:user_version() == 0)
	orm:user_version(10)
	assert(orm:user_version() == 10)
	orm:user_version(0)

	t:eq(orm:migrate(1, migrations), 1)
	t:eq(orm:migrate(1, migrations), 0)

	local models = Models(_models, orm)

	---@type string[]
	local name_tbl = {}
	for c = 0, 0xFF do
		name_tbl[c + 1] = string.char(c)
	end
	local name = table.concat(name_tbl)

	local user_inserted = models.users:create({name = name})
	assert(user_inserted)
	t:eq(user_inserted.id, 1)
	t:eq(user_inserted.name, name)
	t:eq(user_inserted.is_admin, false)
	t:eq(user_inserted.null_flag, nil)
	t:eq(user_inserted.nullable_flag, 1)
	t:eq(user_inserted.role, "user")

	local user = models.users:find({id = 1})
	assert(user)
	t:eq(user.id, 1)
	t:eq(user.name, name)
	t:eq(user.is_admin, false)
	t:eq(user.null_flag, nil)
	t:eq(user.nullable_flag, 1)
	t:eq(user.role, "user")
	t:eq(user.added_column, 0)  -- from migration

	user = models.users:update({
		name = "admin",
		is_admin = true,
		role = "admin",
		null_flag = 1,
		nullable_flag = sql_util.NULL,
	}, {id = 1})[1]
	t:eq(user.name, "admin")
	t:eq(user.is_admin, true)
	t:eq(user.role, "admin")
	t:eq(user.null_flag, 1)
	t:eq(user.nullable_flag, nil)

	orm:update("users", {name = "user"}, {id = 1})
	user = models.users:find({id = 1})
	assert(user)
	t:eq(user.name, "user")

	local post = models.posts:create({user_id = 1, text = "text"})

	models.users:preload({user}, {posts = "user"})
	t:eq(user.posts[1].text, "text")
	t:eq(user.posts[1].user.name, "user")

	t:eq(models.posts:count(), 1)
	models.users:delete({id = 1})
	t:eq(models.posts:count(), 0)

	local t_from_db = {
		is_admin = true,
		role__in = {"user", "admin"},
		role__isnull = true,
		{name = "admin"},
	}
	local t_for_db = {
		is_admin = 1,
		role__in = {0, 1},
		role__isnull = true,
		{name = "admin"},
	}
	t:tdeq(sql_util.conditions_for_db(t_from_db, users.types), t_for_db)

	t:eq(sql_util.conditions({t__isnull = true}), "(`t` IS NULL)")
	t:eq(sql_util.conditions({t__isnull = false}), "")
end

return test
