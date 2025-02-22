local Path = require("Path")

local test = {}

function test.filename(t)
	local a = Path("charts/song/audio.mp3")
	t:eq(a:getName(), "audio.mp3")
	t:eq(a:getName(true), "audio")
	t:eq(a:getExtension(), "mp3")

	local b = Path("charts/song/AuDiO.Mp3")
	t:eq(b:getName(), "AuDiO.Mp3")
	t:eq(b:getName(true), "AuDiO")
	t:eq(b:getExtension(), "mp3")

	local c = Path("charts/song/")
	t:eq(c:getName(), "song")
	t:eq(c:getName(true), "song")
	t:eq(c:getExtension(), nil)

	local d = Path("")
	t:eq(d:getName(), nil)
	t:eq(d:getName(true), nil)
	t:eq(d:getName(), nil)

	local e = Path()
	t:eq(e:getName(), nil)
	t:eq(e:getName(true), nil)
	t:eq(e:getName(), nil)

	local f = Path({})
	t:eq(f:getName(), nil)
	t:eq(f:getName(true), nil)
	t:eq(f:getName(), nil)

	local g = Path({"", "", "", ""})
	t:eq(g:getName(), nil)
	t:eq(g:getName(true), nil)
	t:eq(g:getName(), nil)
end

function test.ext(t)
	local a = Path("img.jpg.png")
	t:eq(a:getExtension(), "png")

	local b = Path("userdata/skins/skin1/10key.skin.lua")
	t:eq(b:getName(), "10key.skin.lua")
	t:eq(b:getName(true), "10key.skin")
	t:eq(b:getExtension(), "lua")

	local c = Path({ "C:/", "Program Files/Program" })
	t:eq(tostring(c), "C:/Program Files/Program")
	t:eq(c:getExtension(), nil)
	t:eq(c:getName(), "Program")
	t:eq(c.driveLetter, "C")

	local d = Path(".bashrc")
	t:eq(d:getExtension(), nil)
	t:eq(d:getName(), "bashrc")

	local e = Path("a.bashrc")
	t:eq(e:getExtension(), "bashrc")

	local f = Path("file.")
	t:eq(f:getExtension(), "")

	local g = Path("..")
	t:eq(g:getExtension(), nil)
end

function test.norm(t)
	local a = Path("/path/to/something/../")
	t:eq(tostring(a), "/path/to/something/../")
	t:eq(tostring(a:normalize()), "/path/to/")

	local b = Path("/path/to/something/..")
	t:eq(tostring(b), "/path/to/something/../") -- .. is a directory
	t:eq(tostring(b:normalize()), "/path/to/")

	local c = Path("/path/to/something/."):normalize()
	t:eq(tostring(c), "/path/to/something/")

	local d = Path("/collection/pack/chart/../bg.png"):normalize()
	t:eq(tostring(d), "/collection/pack/bg.png")

	local f = Path("/collection/pack/chart/../../../../../.."):normalize()
	t:eq(tostring(f), "/")

	local g = Path("/collection/pack/chart/../.."):normalize()
	t:eq(tostring(g), "/collection/")

	local e = Path("/home/user/Games/game1/../game2/../../Dev"):normalize()
	t:eq(tostring(e), "/home/user/Dev")
end

function test.windows(t)
	local a = Path("C:\\collection\\pack\\img.png")
	t:eq(tostring(a), "C:/collection/pack/img.png")
	t:eq(a.driveLetter, "C")

	local b = Path("C:\\collection\\pack\\..\\..\\..\\.."):normalize()
	t:eq(tostring(b), "C:/")
	t:eq(b.driveLetter, "C")
end

function test.concat(t)
	local a = Path("/") .. Path("home/user")
	t:eq(tostring(a), "/home/user")
	t:eq(a.absolute, true)

	local b = Path("userdata/skins") .. Path("manip/4key.skin.lua")
	t:eq(tostring(b), "userdata/skins/manip/4key.skin.lua")
	t:eq(b.absolute, false)

	local c = Path("C:/") .. Path("Program Files") .. Path("Program/Data/Settings.TXT")
	t:eq(tostring(c), "C:/Program Files/Program/Data/Settings.TXT")
	t:eq(c.driveLetter, "C")
	t:eq(c.absolute, true)

	local e = Path("a") .. Path("b") .. Path("c")
	t:eq(tostring(e), "a/b/c")
	t:eq(e.absolute, false)

	local f = Path() .. Path("file.txt")
	t:eq(tostring(f), "file.txt")
	t:eq(f.absolute, false)

	local g = Path() .. Path()
	t:eq(tostring(g), "")
	t:eq(g:isEmpty(), true)

	local h = Path(nil) .. Path("test")
	t:eq(tostring(h), "test")
	t:eq(h.absolute, false)

	local i = Path("dir/") .. Path("file")
	t:eq(tostring(i), "dir/file")

	-- Should the second absoulute path override the first?
	local j = Path("/a") .. Path("/b")
	t:eq(tostring(j), "/a/b") -- meaning this should be `/b` instead
	t:eq(j.absolute, true)

	-- ^^^ But if we override the first, this won't work
	local l = Path("dir") .. Path("/file")
	t:eq(tostring(l), "dir/file")

	local m = Path("C:/a") .. Path("b")
	t:eq(tostring(m), "C:/a/b")
	t:eq(m.driveLetter, "C")

	local n = (Path("a") .. Path("../b")):normalize()
	t:eq(tostring(n), "b")

	local n2 = (Path("/home/user/Games/soundsphere") .. Path("../../")):normalize()
	t:eq(tostring(n2), "/home/user/")

	local o = Path({ "", "a" }) .. Path("b")
	t:eq(tostring(o), "a/b")

	local p = Path({ "/", "home", "user/" })
	t:eq(tostring(p), "/home/user/")
	t:eq(p.absolute, true)
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
	local a = Path("path/to/file"):trimLast()
	t:eq(tostring(a), "path/to/")
	a = a:trimLast()
	t:eq(tostring(a), "path/")
	a = a:trimLast()
	t:eq(tostring(a), "")
	a = a:trimLast()
	t:eq(tostring(a), "")

	local b = Path("/home"):trimLast()
	b = b:trimLast()
	t:eq(tostring(b), "/")
	b = b:trimLast()
	t:eq(tostring(b), "/")

	-- The path is not normalized until you call tostring() or :normalize()
	local c = Path("/home/user/..")
	c = c:trimLast()
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

	local c = (Path("////////") .. Path("../../../..")):normalize()
	t:eq(tostring(c), "/")

	local d = Path(".lol.......")
	t:eq(tostring(d), ".lol.......")
	t:eq(d:isFile(), true)
	t:eq(d:isEmpty(), false)
	t:eq(d:getExtension(), "")

	local e = Path("~/.( ͡° ͜ʖ ͡°)./"):normalize()
	t:eq(tostring(e), "~/.( ͡° ͜ʖ ͡°)./")
end

function test.constructor(t)
	t:has_error(Path, 5)
	t:has_error(Path, print)
end

function test.hidden(t)
	local a = Path("/home/user/.homework/")
	t:eq(a.parts[3].isHidden, true)

	local b = Path("~/.bashrc")
	t:eq(b.parts[2].isHidden, true)

	local c = Path("a.bashrc")
	t:eq(c.parts[1].isHidden, false)

	local d = Path("/home/user/.local/share/.program")
	t:eq(d.parts[1].isHidden, false)
	t:eq(d.parts[2].isHidden, false)
	t:eq(d.parts[3].isHidden, true)
	t:eq(d.parts[4].isHidden, false)
	t:eq(d.parts[5].isHidden, true)

	local e = Path("/home/..")
	t:eq(e.parts[2].isHidden, true)

	local f = Path("/.file.")
	t:eq(f.parts[1].isHidden, true)
	t:eq(f:getExtension(), "")
end

return test
