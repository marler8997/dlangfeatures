# dlangfeatures

A list of features that I think would benefit the D Programming Language.

### pragma(importPath)

Some way of declaring where import source is located.  This is useful for D files that are mean to be run as scripts, and they depend on other libraries (besides druntime/phobos).

```
pragma(importPath, "../mylibs");
```

One use case to think about is when there is a dependency on a library that may live in another repository, or may need to be built beforhand.  In that case you may want to execute code at compile time to find/resolve the library.
```
pragma(importPath, findMyLibrary());
void findMyLibrary()
{
    enum name = "../mylibs";
    if(!exists(name))
    {
        pragma(error, "Error: library '%s' does not exist", name);
    }
}
```

### Automatic library idiom: only link to what you use

This idiom allows external library dependencies to be declared in source code and to only be linked when the corresponding symbols are used.

The idea is that you put all the symbols that require linking to the library in their own module.  This module could also contain a `pragma(lib, "mylibrary.so")` to automatically tell the compiler to link to the library when the module is used.  This special module can be a normal module or a package module (i.e. `<mylibrary>/package.d`) which allows you to create submodules that may contain symbols that don't require linking.

Note that if there are any symbols in the library that don't require linking (i.e. enums/templates/etc), then it's important to put those symbols in a different module so that using them doesn't pull in the module that causes the library to be linked. Of course, if those symbols don't make sense without linking to the library, then there's no need for the separation.

Here's an example of how this idiom would look with the C library:
```D
--- main.d
import libc.stdio;

int main(string[] args)
{
    printf("hello\n".ptr); // Comment out to see that the pragma msg goes away
    return 0;
}
--- libc/package.d
module libc;

pragma(lib, "libc.so");
extern (C) int printf(const char* format, ...);

--- libc/stdio.d
module libc.stdio;

template from(string moduleName)
{
    mixin("import from = " ~ moduleName ~ ";");
}
// Allows printf to be loaded only when it's used
auto printf(T...)(T args) { pragma(inline, true); from!"libc".printf(args); }

```

This still allows the current idom of importing symbols based on the existing C header file organization, and still allows the library to only be linked it is used.

If DRuntime re-organized it's libc modules and runtime module to match this idom, then programs would only need to link with those libraries when they are used.  This will become more useful as the DRuntime itself becomes more modular and really implements "pay for what you use".

One set of libraries that can use this immediately are the Windows libraries.  My `mar` library organizes the Windows' library symbols using this idiom which means the corresponding libraries automatically get linked in whenever their symbols are used.

### DMD Paralell Compilation

### Lazy Imports

In order to delay loading a module, you need to be able to determine which symbols belong to it without loading it.  Unfortunately, this doesn't work with normal imports because they "mix" their symbols into the current scope, i.e.

```D
// The following adds all the symbols from "somemodule" into the current scope
import somemodule;

foo(); // must load "somemodule" because there's no way to know if "somemodule"
       // has a definition for "foo" without loading it
```

Fortunately there are other ways to import modules which can be lazy.  When an import is explicitly restricted to a set of symbols it's easy to determine which symbols belong to that module, i.e.
```D
import somemodule : bar;

foo(); // no need to load "somemodule" because we haven't used the "bar" symbol
```

You can also determine this with "static imports" and "alias imports":
```D
static import somemodule;

foo();            // no need to load "somemodule"
somemodule.bar(); // now we need to load somemodule
```
```D
import s = somemodule;

foo();   // no need to load "somemodule"
s.bar(); // now we need to load somemodule
```

### Lazy AST Generation

According to @dkgroot, most of the memory consumed by the compiler is in AST nodes (around 80% according to him).  Because of this, alot of memory could be saved (and possibly performance as well) if the AST for function bodies were only generated when they were needed.

In order to find the beginning/end of functions, dmd could lex the function body without generating AST.  If lexing is fast, then the compiler could simply save a reference to the function body source to parse again later if needed.  Profiling how fast lexing is would be helpful to determine the right approach here.  You could also have a "fast lexer" which only parses a subset of the full grammar, able to determine the start/end of blocks without having to know the full grammar.

### Compiler Profiling

Built-in profiling to the compiler that can be enabled/disabled at compile-time (so it doesn't affect the released compiler).

### Unittests

Currently if you compile with `-unittest`, the unittests get injected to the beginning of the program.  However, a common use case is that you want to compile in the unittests but only run them once, but then you don't want to have to rebuild the program to remove the unittests.  Some ideas:
* Support some way to run the executable with or without running the unittests
* Provide a tool that can remove unittests from the binary

### Better Error Messages

https://issues.dlang.org/show_bug.cgi?id=16165

#### Good error messages for function argument mismatch

First thing to check is if there is a mismatch in the argument count.  If so, then it likely means the developer either missed or added an extra argument.  In this case, you want to know the count mismatch and the first argument with a type mismatch, i.e.
```
Error: function `foo` takes 10 arguments but got 9
       argument 4 of type `string` is not convertible to `int`
```
In the case there are no type mismatches, this likely means they just forgot the last argument, so the first line of the previous error message alone should suffice.  If there is more than 1 type mismatch, then it's probably better to only print the first one because missing or adding an extra argument is likely to propogate "red herring" errors down the line.

If the argument count is correct, then we must have one or more type mismatches.  In the case of 1 type mismatch, a short error message like this should work well:
```
Error: expected argument 4 of function `foo` to be `int` but got `string`
```
If there is more than one type mismatch, then a multiline error message would probably be better:
```
Error: function `foo` was called with invalid arguments
       argument 4 of type `string` is not convertible to `int`
       argument 8 of type 'MyCoolType!(int,byte)` is not convertible to `AnotherType!(int,byte)`
```

In the case of overloads, just seeing the types is often too little information, however, you also don't want to print the full error message for each overload.  I think the current method of printing all the candidates is great, simply adding a special character that shows where the type mismatches are would work well here.  Also, printing when there is argument count mismatch may be worth the extra characters, i.e.
```
Error: none of the overloads of `foo` are callable using argument types `(int,string)`, candidates are:
       foo() : requires 0 arguments but got 2
       foo(int) : requires 1 argument but got 2
       foo(! short)
       foo(int, ! int)
       foo(! short, ! byte, ! short) : requires 3 arguments but got 2
       foo(int,string, ! short) : requires 3 arguments but got 2
```
Note that type mismatches are indicated by a `!` in the location where a type mismatch occurs.

### template auto value parameter

If you reference the D grammar for templates (See https://dlang.org/spec/template.html), there are currently 5 categories of template parameters:
```
TemplateParameter:
    TemplateTypeParameter
    TemplateValueParameter
    TemplateAliasParameter
    TemplateSequenceParameter
    TemplateThisParameter
```

However there is a hole in this list, namely, generic template value parameters.  The current `TemplateValueParameter` grammar node must explicitly declare a "BasicType":
```
TemplateValueParameter:
    BasicType Declarator
    BasicType Declarator TemplateValueParameterSpecialization
    BasicType Declarator TemplateValueParameterDefault
    BasicType Declarator TemplateValueParameterSpecialization TemplateValueParameterDefault
```
For example:
```
template foo(string value)
{
    ...
}
foo!"hello";
```

However, you can't create a template that accepts a value of *any* type.  This would a good use case for the `auto` keyword, i.e.
```
template foo(auto value)
{
    ...
}
foo!0;
foo!"hello";
foo!'c';
```

This would be a simple change to the grammar, namely,
```
BasicTemplateType:
    BasicType
    auto

TemplateValueParameter:
    BasicTemplateType Declarator
    BasicTemplateType Declarator TemplateValueParameterSpecialization
    BasicTemplateType Declarator TemplateValueParameterDefault
    BasicTemplateType Declarator TemplateValueParameterSpecialization TemplateValueParameterDefault
```

### Context Functions

This is just an idea.  The concept is to allow a function to behave like a "nested function" but be defined outside the function.  This obviously means it would need to be a template since each call to it would have a completely different context/environment.  Therefore, some type of template function should work well, i.e.
```D
void foo(callScope = __CALL_SCOPE__)(...)
{
    // code
}
```

An exmple of where this would be useful is an assert function like this:
```D
void assert(callScope = __CALL_SCOPE__)(bool expr, AST exprAst = __ARG_AST__!expr)
{
    // ...
}
assert(a + b == c);
/*
 inside assert, it can access __CALL_SCOPE__.a, __CALL_SCOPE__.b and __CALL_SCOPE__.c
 so it could print:
 a + b != c (a: 100, b: 234, c: 382)
*/
```

This could also be used to create an "interpolateString" function, i.e.
```D
void interpolate(callScope = __CALL_SCOPE__)(string str)
{
    // perform the interpolation...
}

auto a = 100;
auto b = 20;
assert(interpolate("$a + $b = $(a+b)") ==
    "100 + 20 is 120");
```
