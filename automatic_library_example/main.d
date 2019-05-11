import libc.stdio;

int main(string[] args)
{
    version (UsePrintf)
    {
        pragma(msg, "calling printf...");
        printf("hello\n".ptr);
    }
    else version (NoPrintf)
    {
        pragma(msg, "not calling printf, should not see \"will require linking to libc\"");
    }
    else static assert(0, "provide either -version=UsePrintf or -version=NoPrintf");
    return 0;
}
