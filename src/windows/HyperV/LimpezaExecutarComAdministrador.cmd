TITLE LIMPEZA DO SISTEMA
DEL C:\Windows\Temp /F /S /Q
RD C:\Windows\Temp /S /Q
DEL %temp% /F /S /Q
RD %temp% /S /Q
DEL C:\Windows\Prefetch
RD C:\Windows\Prefetch
Cleanmgr /sageset:65535 & Cleanmgr /sagerun:65535
START cleanmgr.exe /System