# Ciphera

Ciphera is a local-first iOS encryption utility built with SwiftUI. It is designed to make encryption, decryption, digital signatures, file protection, and key management easier to understand and use without requiring an external server.

All cryptographic operations are performed on-device, and private keys are stored in the iOS Keychain.

## Features

### Text Encryption & Decryption
Ciphera can encrypt and decrypt plaintext using:

- AES-256-GCM
- ChaCha20-Poly1305

Two protection modes are available:

- **Secret Mode** — encrypts content using a user-provided secret.
- **Shared Mode** — encrypts content for a recipient using public-key agreement.

Encrypted text is packaged in Ciphera's portable `CP1` format.

### Public-Key Encryption

Ciphera supports public-key agreement using:

- Curve25519
- P-256
- P-384
- P-521

Public keys can be copied and shared using Ciphera's portable key formats:

- `CP-PUB1` — legacy Curve25519 public key format
- `CP-PUB2` — typed public key format

Ciphera also displays fingerprints to help users identify and compare public keys.

### Files & Photos

Files and photos can be encrypted directly from the device.

The encrypted content is exported as a `.txt` Ciphera package using the `CPFILE1` format instead of displaying a large encrypted payload on screen.

The workflow supports:

- Selecting photos from Gallery
- Selecting documents from Files
- Encrypting files using Secret or Shared mode
- Importing encrypted `.txt` packages
- Decrypting and previewing restored files
- Saving or sharing encrypted and decrypted results

### Digital Signatures & Autographs

Ciphera can digitally sign and verify content using:

- Ed25519
- P-256 ECDSA
- P-384 ECDSA
- P-521 ECDSA

Signed content is stored in a portable `CP-SIG1` package.

The Sign & Verify feature can:

- Sign plaintext
- Attach a drawn autograph to signed content
- Copy or share signed packages
- Verify imported signed packages
- Import autograph packages from Gallery or Files
- Display verification results on a dedicated result page
- Show signed content, autograph, signer fingerprint, and creation information after successful verification

### Key Management

Ciphera generates and manages local cryptographic identities.

Private keys are stored in the iOS Keychain and are not displayed during normal use.

The **My Key** section allows users to:

- View their public key
- Copy their public key
- View the public-key fingerprint
- Back up their Curve25519 private key
- Restore an existing private-key backup

Password-protected private-key backups use the `CP-PRIV2` format.

Legacy `CP-PRIV1` backups are also supported for restoration compatibility.

### CP1 Inspector

The CP1 Inspector allows users to inspect the structure and metadata of supported Ciphera packages without needing to manually decode the payload.

### Crypto Dictionary & Tutorials

Ciphera includes beginner-friendly learning tools that explain common cryptographic concepts and guide users through important app features.

These are available under **Tools** so the main Encrypt and Decrypt workflows remain focused and uncluttered.

## How to Use

### Encrypt a Message

1. Open **Encrypt**.
2. Enter the plaintext you want to protect.
3. Choose **Secret** or **Shared** mode.
4. Select the encryption algorithm.
5. For Secret mode, enter your secret.
6. For Shared mode, paste the recipient's public key.
7. Tap **Encrypt**.
8. Copy or share the generated `CP1` package from the result page.

### Decrypt a Message

1. Open **Decrypt**.
2. Paste the `CP1` encrypted package.
3. Enter the required secret or use the appropriate local private key.
4. Tap **Decrypt**.
5. View the recovered plaintext on the result page.

### Encrypt a File or Photo

1. Open **Files & Photos**.
2. Choose **Encrypt**.
3. Select a photo from Gallery or a document from Files.
4. Choose the protection mode and required key or secret.
5. Tap **Encrypt**.
6. Save or share the generated `.txt` Ciphera package.

### Decrypt a File or Photo

1. Open **Files & Photos**.
2. Choose **Decrypt**.
3. Import a Ciphera `.txt` package.
4. Provide the required secret when necessary.
5. Tap **Decrypt**.
6. Preview, save, or share the restored file.

### Sign Content

1. Open **Sign & Verify**.
2. Select **Sign**.
3. Enter the content you want to sign.
4. Optionally add a handwritten autograph.
5. Choose the signing algorithm.
6. Tap **Sign**.
7. Copy or share the generated `CP-SIG1` package.

### Verify a Signature

1. Open **Sign & Verify**.
2. Select **Verify**.
3. Paste or import a `CP-SIG1` signed package.
4. Tap **Verify Signature**.
5. Ciphera opens a dedicated verification result page.
6. If valid, the signed content, autograph, signer information, and related details are displayed.

### Back Up a Private Key

1. Open **My Key**.
2. Select the private-key backup option.
3. Authenticate with the device when requested.
4. Enter and confirm a backup password.
5. Create the backup.
6. Store the resulting `CP-PRIV2` package securely.

### Restore a Private Key

1. Open **My Key**.
2. Open the restore option.
3. Paste the private-key backup.
4. Enter the backup password when required.
5. Authenticate with the device.
6. Confirm the restore operation.

Restoring a private key replaces the current corresponding key stored by Ciphera.

## Security Model

Ciphera is designed around local processing:

- Encryption and decryption happen on-device.
- Private cryptographic keys are stored in the iOS Keychain.
- Sensitive private-key operations can require device authentication.
- Plaintext and encrypted file payloads are not intentionally stored as a remote account or cloud database.
- AES-GCM and ChaCha20-Poly1305 provide authenticated encryption.
- Digital signatures allow users to verify whether signed content has been modified.

The current human-secret key derivation implementation is intended for learning and prototype use. It should not be treated as an independently audited production password-hardening design.

Users are responsible for protecting their secrets, private-key backups, and recovery passwords.

## Portable Formats

Ciphera uses several text-based package formats:

| Format | Purpose |
| --- | --- |
| `CP1` | Encrypted plaintext |
| `CPFILE1` | Encrypted files and photos |
| `CP-PUB1` | Legacy Curve25519 public key |
| `CP-PUB2` | Typed public key |
| `CP-PRIV1` | Legacy private-key backup |
| `CP-PRIV2` | Password-protected private-key backup |
| `CP-SIG1` | Digitally signed content and autograph packages |

## Technology

Ciphera is built using native Apple frameworks and does not require third-party UI or cryptography libraries.

- Swift
- SwiftUI
- CryptoKit
- Security / Keychain Services
- LocalAuthentication
- PhotosUI
- UniformTypeIdentifiers
- PencilKit

## Architecture

The project uses a feature-first MVVM structure.

- **Views** handle presentation and user interaction.
- **ViewModels** manage screen state, validation, navigation state, and service calls.
- **Core Crypto services** perform cryptographic operations.
- **Security services** handle Keychain storage and device authentication.
- **Models** represent encryption, decryption, signature, and supporting result data.

## Requirements

- Xcode
- iOS 17.0 or later
- iPhone or iPhone Simulator

Some functionality, such as device authentication, Gallery access, and file handling, is best tested on a physical iPhone.

## Running the Project

1. Clone the repository:

```bash
git clone https://github.com/Cadburyy/Ciphera.git
```

2. Open the project:

```bash
cd Ciphera
open Ciphera.xcodeproj
```

3. Select an iPhone Simulator or connected iPhone.
4. Build and run the project from Xcode.

## Disclaimer

Ciphera is an educational and experimental cryptography project. It has not undergone an independent professional security audit and should not be relied on as the sole protection mechanism for highly sensitive or mission-critical information.
