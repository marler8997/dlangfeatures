module libc.stdio;

template from(string moduleName)
{
    mixin("import from = " ~ moduleName ~ ";");
}
auto printf(T...)(T args) { pragma(inline, true); from!"libc".printf(args); }
