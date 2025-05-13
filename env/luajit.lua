local pkg = require("aqua.pkg")

pkg.add()
pkg.add("aqua")
pkg.add("tree/share/lua/5.1")
pkg.addc("tree/lib/lua/5.1")

pkg.export_lua()
