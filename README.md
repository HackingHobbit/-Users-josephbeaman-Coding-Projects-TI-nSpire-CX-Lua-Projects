# -Users-josephbeaman-Coding-Projects-TI-nSpire-CX-Lua-Projects
These projects were created on and for my TI-Nspire CX calculator.  GTK (Graphics Toolkit) is required for all of the other projects.  It provides the GUI framework, page management,
etc.  Since the TI-Nspire doesn't give you access to the file system from within a Lua app, I had to find some creative workarounds.  The toolkit is stored as a series of string 
variables that are stored as public libraries.  When an app (Lua script) requires them, it loads, compiles, and executes the code.  I broke up the library into modules so as to
reduce the time needed to load the library for those apps that didn't require all of it and to overcome the TI's limit on the length of string variables.

Each of these projects, including the GTK and others, was typed into the calculator from it's own keyboard without the use of a computer.  The code is reasonably efficient--it had
to be just to run with the small amount of resources available to the device!  I hope you enjoy the apps as much as I enjoyed creating them.

To see a video demo of some of the projects, click the link below:

https://drive.google.com/file/d/1-C7GyXRliFUJv4t28lPmUZBR6Cu_ul6W/view?usp=sharing
