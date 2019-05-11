module libc;

pragma(msg, "requires linking to libc...");
extern (C) int printf(const char* format, ...);
