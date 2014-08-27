CCAPT
=====

Developed and maintained by: LNETeam

USAGE: apt-get {install/remove/update} [package name]

Install: Our installation process works by developers adding repo locations to their projects hosted at our site. We store web-location,project dependencies, and information in a database which can be accessed through our CC app. Once installed, CCAPT will add the projects to a type of registry, tracking installed files (and locations of). If you would like to use CCAPT internally, the API is embedded...

API:

You can use the built-in registry to look up programs. For example: "ccapt.IndexProgram("myprogram")". This will return a table containing information about install date, file locations, and entry points (aka startups, homepages). The developer, should include a single file in the root of their Github repo which contains a list of dependencies, entry points, and install locations (CCAPT collects these anyway, but to make life easier incase of a failure, it can check).

Example:

install = {}
install.PostAction = function() print("Hi") end --This is the stuff executed after apt-get has finished
install.PreAction = function() print("Derp") end --This is the stuff executed prior apt-get beginning
install.Dependencies = {} --This list should contain the names of apis/programs you package needs. The names should be relevant to lneteam repos. CCAPT will resolve them and get them as well, a streamlined process. Much like install mysql on a linux server via command line. Configure one, move on.
install.InstallHierarchy = {{"/os/myapi","superOS/os/myapi"},{},{}} --This table contains information to distribute the package to its proper location. The first value contains the repo location, the second contains install location.
return install

Thats it! The file should be called "INSTALL" (without quotes). We'll take it from there.

