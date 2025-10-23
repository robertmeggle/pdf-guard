# PDF-Guard

Windows Explorer context menu tool to protect PDF files with a password.  
This project uses [qpdf](https://qpdf.sourceforge.io/) under the hood.

## Current status

- Password protection implemented (set user/owner password)  
- Planned: password removal, watermarking, and more PDF utilities  

## Requirements

- You need to download and install the **portable qpdf** binaries yourself.  
- Place the extracted qpdf files inside the `extTools/` directory.  
- Only `readme.md` is tracked in `extTools/`; everything else is ignored in `.gitignore`.

## Installation

1. Run `install.bat` to copy the scripts into your `%LOCALAPPDATA%\Encrypt-PDF` directory and create the Explorer context menu entry.  
2. After that, right-click any `.pdf` in Explorer → *More options* → **PDF mit Passwort schützen**.  

## Uninstall

Run `uninstall.bat` to remove the context menu entry and delete `%LOCALAPPDATA%\Encrypt-PDF`.
