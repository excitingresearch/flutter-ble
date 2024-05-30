@ECHO off
SETLOCAL EnableExtensions EnableDelayedExpansion


SET com_all=
SET com_last=none
SET com_count=0
FOR /F "tokens=* USEBACKQ" %%F IN (`mode ^| find "COM"`) DO (
  SET com_line=%%F
  IF "Q!com_line:Status for device COM=!" == "Q!com_line!" (
    REM Line does not have form 'Status for device COMxx' - ignore
  ) ELSE (
    SET com_port=!com_line:~18,-1!
    SET com_last=!com_port!
    SET com_all=!com_all! !com_port! &REM with trainling space
    SET /a com_count=!com_count!+1
  )
)



IF %com_count% EQU 0 (
  ECHO "nothing"
)

IF %com_count% EQU 1 (
  SET com_sel=!com_last!
  ECHO Auto selected: !com_sel!
  GOTO :selected
) ELSE (
  ECHO "MULTIPLE FOUND"
)



:selected


pause


"esptool.exe" --chip esp32c3 --port !com_sel! --baud 921600  --before default_reset --after hard_reset write_flash  -z --flash_mode dio --flash_freq 80m --flash_size 4MB 0x0 "fw-files-win/moody_v4_0_5_fw.ino.bootloader.bin" 0x8000 "fw-files-win/moody_v4_0_5_fw.ino.partitions.bin" 0xe000 "fw-files-win/boot_app0.bin" 0x10000 "fw-files-win/moody_v4_0_5_fw.ino.bin" 
pause

:abort
echo abort