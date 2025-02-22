local Path = require("Path")

local test = {}

function test.filename(t)
	local a = Path("charts/song/audio.mp3")
	t:eq(a:getFileName(), "audio.mp3")
	t:eq(a:getFileName(true), "audio")
	t:eq(a:getExtension(), "mp3")

	local b = Path("charts/song/AuDiO.Mp3")
	t:eq(b:getFileName(), "AuDiO.Mp3")
	t:eq(b:getFileName(true), "AuDiO")
	t:eq(b:getExtension(), "mp3")

	local c = Path("charts/song/")
	t:eq(c:getFileName(), "")
	t:eq(c:getFileName(true), "")
	t:eq(c:getExtension(), "")

	local d = Path("")
	t:eq(d:getFileName(), "")
	t:eq(d:getFileName(true), "")
	t:eq(d:getFileName(), "")

	local e = Path()
	t:eq(e:getFileName(), "")
	t:eq(e:getFileName(true), "")
	t:eq(e:getFileName(), "")

	local f = Path({})
	t:eq(f:getFileName(), "")
	t:eq(f:getFileName(true), "")
	t:eq(f:getFileName(), "")

	local g = Path({"", "", "", ""})
	t:eq(g:getFileName(), "")
	t:eq(g:getFileName(true), "")
	t:eq(g:getFileName(), "")
end

function test.ext(t)
	local a = Path("img.jpg.png")
	t:eq(a:getExtension(), "png")

	local b = Path("userdata/skins/skin1/10key.skin.lua")
	t:eq(b:getFileName(), "10key.skin.lua")
	t:eq(b:getFileName(true), "10key.skin")
	t:eq(b:getExtension(), "lua")

	local c = Path({ "C:/", "Program Files/Program" })
	t:eq(tostring(c), "C:/Program Files/Program")
	t:eq(c:getExtension(), "")
	t:eq(c:getFileName(), "Program")
	t:eq(c.driveLetter, "C")

	local d = Path(".bashrc")
	t:eq(d:getExtension(), "")

	local e = Path("a.bashrc")
	t:eq(e:getExtension(), "bashrc")
end

function test.norm(t)
	local a = Path("/path/to/something/../")
	t:eq(tostring(a), "/path/to/")

	local b = Path("/path/to/something/..")
	t:eq(tostring(b), "/path/to/")

	local c = Path("/path/to/something/.")
	t:eq(tostring(c), "/path/to/something/")

	local d = Path("/collection/pack/chart/../bg.png")
	t:eq(tostring(d), "/collection/pack/bg.png")

	local f = Path("/collection/pack/chart/../../../../../..")
	t:eq(tostring(f), "/")

	local g = Path("/collection/pack/chart/../..")
	t:eq(tostring(g), "/collection/")

	local e = Path("/home/user/Games/game1/../game2/../../Dev")
	t:eq(tostring(e), "/home/user/Dev")
end

function test.windows(t)
	local a = Path("C:\\collection\\pack\\img.png")
	t:eq(tostring(a), "C:/collection/pack/img.png")
	t:eq(a.driveLetter, "C")

	local b = Path("C:\\collection\\pack\\..\\..\\..\\..")
	t:eq(tostring(b), "C:/")
	t:eq(b.driveLetter, "C")
end

function test.concat(t)
	local a = Path("/") .. Path("home/user")
	t:eq(tostring(a), "/home/user")
	t:eq(a.leadingSlash, true)

	local b = Path("userdata/skins") .. Path("manip/4key.skin.lua")
	t:eq(tostring(b), "userdata/skins/manip/4key.skin.lua")
	t:eq(b.leadingSlash, false)

	local c = Path("C:/") .. Path("Program Files") .. Path("Program/Data/Settings.TXT")
	t:eq(tostring(c), "C:/Program Files/Program/Data/Settings.TXT")
	t:eq(c.driveLetter, "C")
	t:eq(b.leadingSlash, false)

	local e = Path("a") .. Path("b") .. Path("c")
    t:eq(tostring(e), "a/b/c")
    t:eq(e.leadingSlash, false)

    local f = Path() .. Path("file.txt")
    t:eq(tostring(f), "file.txt")
    t:eq(f.leadingSlash, false)

    local g = Path() .. Path()
    t:eq(tostring(g), "")
    t:eq(g:isEmpty(), true)

    local h = Path(nil) .. Path("test")
    t:eq(tostring(h), "test")
    t:eq(h.leadingSlash, false)

    local i = Path("dir/") .. Path("file")
    t:eq(tostring(i), "dir/file")

	-- Should the second absoulute path override the first?
    local j = Path("/a") .. Path("/b")
    t:eq(tostring(j), "/a/b") -- meaning this should be `/b` instead
    t:eq(j.leadingSlash, true)

	-- ^^^ But if we override the first, this won't work
    local l = Path("dir") .. Path("/file")
    t:eq(tostring(l), "dir/file")

    local m = Path("C:/a") .. Path("b")
    t:eq(tostring(m), "C:/a/b")
    t:eq(m.driveLetter, "C")

    local n = Path("a") .. Path("../b")
    t:eq(tostring(n), "b")

    local n2 = Path("/home/user/Games/soundsphere") .. Path("../../")
    t:eq(tostring(n2), "/home/user/")

    local o = Path({ "", "a" }) .. Path("b")
    t:eq(tostring(o), "a/b")
end

function test.dirOrFile(t)
	local a = Path("file.txt")
	t:eq(a:isFile(), true)
	t:eq(a:isDirectory(), false)

	local b = Path("file")
	t:eq(b:isFile(), true)
	t:eq(b:isDirectory(), false)

	local c = Path("/file")
	t:eq(c:isFile(), true)
	t:eq(c:isDirectory(), false)

	local d = Path("dir/")
	t:eq(d:isFile(), false)
	t:eq(d:isDirectory(), true)

	local f = Path("/dir/")
	t:eq(f:isFile(), false)
	t:eq(f:isDirectory(), true)

	local g = Path()
	t:eq(g:isEmpty(), true)
	t:eq(g:isFile(), false)
	t:eq(g:isDirectory(), false)
end

function test.trim(t)
	local a = Path("path/to/file")
	a:trimLast()
	t:eq(tostring(a), "path/to/")
	a:trimLast()
	t:eq(tostring(a), "path/")
	a:trimLast()
	t:eq(tostring(a), "")
	a:trimLast()
	t:eq(tostring(a), "")

	local b = Path("/home")
	b:trimLast()
	t:eq(tostring(b), "/")
	b:trimLast()
	t:eq(tostring(b), "/")

	-- The path is not normalized until you call tostring() or :normalize()
	local c = Path("/home/user/..")
	c:trimLast()
	t:eq(tostring(c), "/home/user/")
end

function test.toFileToDir(t)
	local a = Path("dir/")
	t:eq(a:isDirectory(), true)
	t:eq(tostring(a), "dir/")

	a:toFile()
	t:eq(a:isFile(), true)
	t:eq(tostring(a), "dir")

	local b = Path("/dir/file.txt")
	b:toDirectory()
	t:eq(b:isDirectory(), true)
	t:eq(tostring(b), "/dir/file.txt/")
end

function test.weird(t)
	local a = Path("///////////////////")
	t:eq(tostring(a), "/")

	local b = Path("//////////home/////////")
	t:eq(tostring(b), "/home/")

	local c = Path("////////") .. Path("../../../..")
	t:eq(tostring(c), "/")

	local d = Path(".lol.......")
	t:eq(tostring(d), ".lol.......")
	t:eq(d:isFile(), true)
	t:eq(d:isEmpty(), false)
	t:eq(d:getExtension(), "")
end

function test.constructor(t)
	t:has_error(Path, 5)
	t:has_error(Path, print)
end

return test
