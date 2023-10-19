local LjsqliteDatabase = require("rdb.LjsqliteDatabase")
local TableOrm = require("rdb.TableOrm")
local relations = require("rdb.relations")
local Models = require("rdb.Models")
local sql_util = require("rdb.sql_util")

local users = {}
package.loaded["rdb.models.users"] = users

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

users.types = {
	is_admin = "boolean",
	role = {
		user = 0,
		admin = 1,
	}
}

users.relations = {
	posts = {has_many = "posts", key = "user_id"},
}

local posts = {}
package.loaded["rdb.models.posts"] = posts

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

local test = {}

function test.all(t)
	local db = LjsqliteDatabase()
	db:open(":memory:")

	db:exec(users.create_query)
	db:exec(posts.create_query)
	db:exec("PRAGMA foreign_keys = ON;")

	local orm = TableOrm(db)
	local models = Models("rdb.models", orm)

	local name = ""
	for c = 0, 0xFF do
		name = name .. string.char(c)
	end

	local user_inserted = models.users:insert({name = name})
	assert(user_inserted)
	t:eq(user_inserted.id, 1)
	t:eq(user_inserted.name, name)
	t:eq(user_inserted.is_admin, false)
	t:eq(user_inserted.null_flag, nil)
	t:eq(user_inserted.nullable_flag, 1)
	t:eq(user_inserted.role, "user")

	local user = models.users:select({id = 1})[1]
	assert(user)
	t:eq(user.id, 1)
	t:eq(user.name, name)
	t:eq(user.is_admin, false)
	t:eq(user.null_flag, nil)
	t:eq(user.nullable_flag, 1)
	t:eq(user.role, "user")

	user:update({
		name = "admin",
		is_admin = true,
		role = "admin",
		null_flag = 1,
		nullable_flag = sql_util.NULL,
	})
	t:eq(user.name, "admin")
	t:eq(user.is_admin, true)
	t:eq(user.role, "admin")
	t:eq(user.null_flag, 1)
	t:eq(user.nullable_flag, nil)

	orm:update("users", {name = "user"}, {id = 1})
	user:select()
	t:eq(user.name, "user")

	local post = models.posts:insert({user_id = 1, text = "text"})

	relations.preload({user}, {posts = "user"})
	t:eq(user.posts[1].text, "text")
	t:eq(user.posts[1].user.name, "user")

	local _posts = models.posts:select()
	t:eq(#_posts, 1)

	user:delete()

	local _posts = models.posts:select()
	t:eq(#_posts, 0)
end

return test
