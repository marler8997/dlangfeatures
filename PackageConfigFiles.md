# Package Config Files

This is an idea to make D Libraries alot easier to use/maintain. Some of the problems it addresses are:

1. Allowing a library to declare dependency information/language version information
2. Keep the "Import directories" -I in sync with the modules to be compiled (The modules given on the command line)
3. Address some of the issues with pre-compiled libraries such as keeping any compile "versions" the library requires.
4. Allow multiple packages to live in the same directory without exposing them all.
5. Address redundant directory names by allowing the configuration to specify which files/directories are in each package.
6. Decrease the number of filesystem operations it takes to discover modules.


The idea here is to add support for "package configuration files".  These package configuration files can be passed to the compiler directory on the command line, i.e.

dmd ../mylibrary/foo.dpkg  main.d

The `foo.dpkg` file contains information about a dpkg, i.e.

```
# this says that the 'bar' directory contains modules in the foo package
dir bar
# this just adds a single file to the foo package
file baz/file.d
```

