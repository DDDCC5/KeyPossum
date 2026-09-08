# Security and input recovery

KeyPossum is not an access-control or security-lock product. Its supported purpose is temporarily suppressing input for cleaning.

Input must fail open on recovery faults. Do not change the implementation to disable device drivers or retain a permanent block after a process exits. Keep interception code separate from UI work, do not log key events, and validate saved settings.

This repository has not yet enabled a private vulnerability-reporting channel. After publishing, maintainers should enable GitHub private vulnerability reporting under repository Settings → Code security. Use the resulting Security → Report a vulnerability entry for sensitive reports. Until that is configured, do not post exploit details or personal information in a public issue.

Reproducible ordinary input leaks can be reported publicly with OS/app version and device model. An alpha build must not be described as universally verified.
