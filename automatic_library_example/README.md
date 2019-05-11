
### Expected output
```bash
$ dmd -version=UsePrintf main.d
calling printf...
requires linking to libc...

$ dmd -version=NoPrintf main.d
not calling printf, should not see "will require linking to libc"

```
