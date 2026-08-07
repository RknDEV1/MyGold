# MyGold API — iOS Authentication and Licence Verification Framework

A lightweight Objective-C++ dynamic library (`.dylib`) and Debian package (`.deb`) designed for hardware ID (HWID) extraction, licence key validation, and runtime UI injection on iOS platforms.

---

## Architecture Overview

The codebase is structured into modular components decoupling the public interface contract, visual overlay components, external configuration specifications, and the build pipeline:

| Component | Description |
| :--- | :--- |
| `MyGoldAPI.h` | Public API header exposing the singleton lifecycle and verification flow control methods. |
| `MyGoldAPI.mm` | Implementation providing hardware identifier computation, network verification tasks, and UIKit overlay windows. |
| `MyGoldConfig.example.h` | Template configuration header declaring placeholder macro definitions. |
| `entry.mm` | Dynamic library entry point executing constructor routines upon process initialisation. |
| `Makefile` | Theos compilation specification targeting the `arm64` architecture. |
| `control` | Debian package control metadata for package management systems (dpkg/Cydia/Sileo). |
| `MyGoldAPI.plist` | MobileSubstrate filter configuration defining target process injection rules. |
| `build.sh` | Ephemeral build orchestration script managing dependency provisioning and compilation output. |

---

## Configuration Setup (`MyGoldConfig.h`)

For security compliance, production endpoints and authentication tokens are excluded from version control via `.gitignore`. 

Before initialising the build pipeline, create the local configuration header from the provided template:

```bash
cp MyGoldConfig.example.h MyGoldConfig.h
```

Populate `MyGoldConfig.h` with your valid environment credentials:

```objc
#ifndef MyGoldConfig_h
#define MyGoldConfig_h

#define kMyGoldAPIUrl @"https://your-api-endpoint.com/api/public/verify"
#define kMyGoldPackageID @"YOUR_PACKAGE_ID"
#define kMyGoldPackageToken @"YOUR_PACKAGE_TOKEN"
#define kMyGoldXORKey "YOUR_XOR_KEY"

#endif
```

---

## Build Environment Execution

### Prerequisites
An Ubuntu/WSL2 Linux environment with system dependencies (`clang`, `lld`, `make`, `git`, `curl`, `zip`, `unzip`).

### Compilation Pipeline
Execute the automated build script from the repository root:

```bash
./build.sh
```

The build script automatically provisions an isolated compilation workspace (`.build_temp`), clones the necessary iOS SDK headers and code signing utilities (`ldid`), compiles both the dynamic library and the Debian package, outputs the compiled binaries to `./build/`, and purges all intermediate artifacts upon exit.

---

## Target Binary Outputs

Upon successful execution, the compiled artifacts are written to the `./build/` directory:

- `build/MyGoldAPI.dylib` — Dynamic library for jailed IPA injection protocols.
- `build/com.snowzdev.mygoldapi_1.0.0_iphoneos-arm64.deb` — Debian package for jailbroken iOS environments.

---

## Binary Injection Protocols

### Jailed Environment (.ipa)
To inject `MyGoldAPI.dylib` into a target application package:

- **Sideloadly / Azule / ESign / TrollStore:** Load the target `.ipa` package, specify `build/MyGoldAPI.dylib` within the dynamic library injection settings, and execute the signing workflow.

### Jailbroken Environment
To install the Debian package via package manager:

```bash
dpkg -i build/com.snowzdev.mygoldapi_1.0.0_iphoneos-arm64.deb
```
