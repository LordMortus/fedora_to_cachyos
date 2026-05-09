@echo off
:: ================================================================
:: restart-sunshine.bat
:: Restarts the Sunshine game streaming service on your Fedora VM
:: via SSH. Run this if Moonlight gives a 503 error when connecting.
::
:: SETUP REQUIRED BEFORE USE:
:: 1. Complete the SSH setup steps in SSH-Setup-and-503-Fix.txt
:: 2. Edit the two lines replacing <user> with your user name and
:: 3. <vm-ip> with the IP of the VM you want to connect to.
:: ================================================================

:: Your Fedora VM username
:: Replace dan with whatever username you created during Fedora install
:: Example: set VM_USER=john
set VM_USER=<user>

:: Your Fedora VM IP address
:: Find it by running "ip addr show" on the VM
:: Example: set VM_IP=192.168.1.100
set VM_IP=<vm-ip>

:: ================================================================
:: DO NOT EDIT BELOW THIS LINE
:: ================================================================

echo.
echo Restarting Sunshine on %VM_USER%@%VM_IP%...
echo.

ssh %VM_USER%@%VM_IP% "systemctl --user restart app-dev.lizardbyte.app.Sunshine"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Sunshine restarted successfully!
    echo Wait 2-3 seconds then reconnect in Moonlight.
) else (
    echo.
    echo ERROR: Could not connect to %VM_IP%
    echo.
    echo Possible causes:
    echo   - VM is not running
    echo   - IP address is wrong
    echo   - SSH is not set up yet ^(see SSH-Setup-and-503-Fix.txt^)
    echo   - VM username is wrong
)

echo.
pause
