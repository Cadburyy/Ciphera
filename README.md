# Ciphera — Phase 10

Local-first SwiftUI encryption utility for iPhone.

## Current features
- Apple HIG-style TabView + NavigationStack hierarchy
- Beginner onboarding plus a reusable Guided Tutorials center
- Text encryption/decryption with AES-256-GCM or ChaCha20-Poly1305
- Secret mode using the current learning KDF: SHA-256 + HKDF-SHA256
- Recipient encryption using Curve25519, P-256, P-384, or P-521 key agreement
- Legacy `CP-PUB1` Curve25519 keys plus `CP-PUB2` typed public keys
- Public-key fingerprints and QR sharing
- Curve25519 `CP-PRIV1` and password-protected `CP-PRIV2` recovery
- File and photo encryption through copyable `CPFILE1` Base64 text packages (prototype limit: 20 MB)
- Digital signing and verification with Ed25519, P-256 ECDSA, P-384 ECDSA, or P-521 ECDSA
- Portable `CP-SIG1` signature packages
- CP1 inspector
- Private keys stored in iOS Keychain

## Beginner-friendly design
The normal Encrypt and Decrypt tabs remain simple. More technical features live under **Tools** so the main workflow is not overloaded. Guided Tutorials explain the intent first and the cryptography second.

## Security note
The current human-secret KDF is intentionally retained from the earlier learning build for reliability and CyberChef compatibility. It is not a production password-hardening KDF; a future production release should use an independently audited password-hardening design.

## Architecture

The app now uses a feature-first MVVM layout. Main interactive screens use dedicated `ObservableObject` view models for state, validation, errors, and service calls. See `ARCHITECTURE.md` for the folder map and responsibility rules.
