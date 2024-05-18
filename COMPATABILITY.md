# ReBlock Compatability
This file tells you about the requirements to use ReBlock, although you probably wouldn't need this because literally every Windows 10/11 device in existence could run this.

## Windows
You need at least **Windows 7** or newer to run ReBlock. ReBlock requires **Command Prompt and PowerShell**.

This is a list of supported Windows operating systems below that are known to work:
| OS | PowerShell Version |
| - | - |
| Windows 7 | PowerShell 5.1 |
| Windows 8 | PowerShell 7x |
| Windows 8.1 | PowerShell 7x |
| Windows 10 Home | PowerShell 7x |
| Windows 10 Pro | PowerShell 7x |
| Windows 10 Education | PowerShell 7x |
| Windows 11 Home | PowerShell 7x |
| Windows 11 Pro | PowerShell 7x |
| Windows 11 Education | PowerShell 7x |
| Windows Server 2019 | PowerShell 5x |
| Windows Server 2022 | PowerShell 5.1 (can update to 7x) |

Below is a list of known working PowerShell versions that work on ReBlock:
| Version | Minimum Supported Systems | Supported Architechures |
| - | - | - |
| 5.0/5.1 | Windows 7 SP1, Windows Server 2008 R2 SP1, Windows 8, Windows Server 2012 | x86, x64 |
| Core 6.x | Windows 7, Windows Server 2008 R2 | x86, x64 |
| **7.x (Latest)** | Windows 8.1, Windows Server 2012 R2 | x86, x64 |
> [!IMPORTANT]
> Windows 11 only supports the x64 architechure.

Unsupported versions of Windows at the moment:
| OS | ReBlock Version | Reason | PowerShell Version |
| - | - | - | - |
Windows 10 S | All | S mode won't allow for execution of unapproved Microsoft executables/scripts | PowerShell 7x |
| Windows 11 S | All | Same reason as Windows 10 S | PowerShell 7x |
