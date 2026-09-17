@echo off
PowerShell -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0F8ForSafeMode.ps1""' -Verb RunAs}"
