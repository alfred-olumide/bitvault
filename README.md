# BitVault – Sovereign Asset Registry

**A decentralized, verifiable custody and provenance framework for digital assets, secured by Bitcoin via Stacks.**

---

## 🌐 Overview

**BitVault** is a Clarity smart contract system that provides sovereign control and fine-grained access permissions over digital assets registered on-chain. Built atop Bitcoin's security model via the Stacks Layer 2, BitVault enables asset custodians to manage, validate, transfer, and audit the provenance of digital assets in a trust-minimized, cryptographically verifiable manner.

This system is ideal for applications requiring immutable asset registration, decentralized audit trails, and selective third-party verification access — such as digital rights management, physical-digital twin registries, or secure asset custody infrastructure.

---

## 🧩 Key Features

* **Sovereign Custody:** Only asset custodians can register, update, transfer, or cancel asset records.
* **Verifiable Provenance:** Every asset lifecycle change is anchored on-chain with full traceability.
* **Granular Access Control:** Custodians can grant/revoke read-access permissions to specific principals.
* **Metadata Richness:** Includes extended descriptors and tagged classification schemes.
* **Audit & Validation:** Enables permissioned parties to validate asset state, custody history, and integrity.

---

## ⚙️ System Architecture

### 🏛 Components

| Component              | Description                                                                            |
| ---------------------- | -------------------------------------------------------------------------------------- |
| `asset-catalog`        | Main registry map holding all asset metadata, ownership, and classification.           |
| `authorization-matrix` | Access control layer mapping asset IDs to third-party principals with read-access.     |
| `registry-sequence`    | Global asset sequence generator for unique asset IDs.                                  |
| `admin-authority`      | Administrative actor (typically contract deployer or governance-controlled principal). |

### Core Actors

* **Custodian (Principal):** Primary controller of an asset’s state and permissions.
* **Authorized Party (Principal):** Granted read-only rights to asset metadata for validation.
* **Admin Authority:** System-level actor with emergency override capability.

---

## 📜 Contract Architecture

The BitVault contract is composed of well-encapsulated functional domains:

### 1. **Asset Lifecycle**

* `register-new-asset`: Creates a new asset with complete metadata.
* `update-asset-registration`: Modifies metadata fields (descriptor, volume, tags).
* `cancel-asset-registration`: Deletes an asset from the registry.
* `transfer-asset-custody`: Reassigns custody to another principal.

### 2. **Authorization Management**

* `authorize-third-party-access`: Grants view permissions to another user.
* `revoke-third-party-access`: Revokes access from a third party.
* `check-authorization-status`: Queries the authorization state of a principal.

### 3. **Metadata Management**

* `extend-classification-tags`: Appends classification tags to an asset.
* `update-asset-volume`: Updates the quantitative volume field of an asset.

### 4. **Verification & Auditing**

* `validate-asset-integrity`: Confirms custodial state and asset integrity against expectations.
* `get-asset-classification`: Retrieves classification tags for an asset.

### 5. **Administrative Controls**

* `apply-emergency-restriction`: Placeholder hook for future enforcement of emergency restrictions.

---

## 🗂️ Data Flow Summary

```plaintext
[ tx-sender ]
     ↓
[ register-new-asset ]
     ↓
[ asset-catalog ← stores metadata ]
     ↓
[ authorization-matrix ← initialized with tx-sender access ]
     ↓
[ Transfer or Access Management invoked as needed ]
     ↓
[ Verification & Audit via read-access or admin privileges ]
```

---

## 🔒 Security Model

* **Immutable State Anchoring:** All changes are enforced through Clarity's deterministic transaction model.
* **Access Gated by Ownership:** Write operations require strict custodian match.
* **Read Gated by Access Matrix:** Non-custodians must be explicitly authorized.
* **Defensive Validations:** Strong validation against malformed metadata, unauthorized changes, and overflows.

---

## 🛠 Deployment & Usage

### Deploying the Contract

```bash
clarinet check
clarinet deploy
```

### Calling Functions

Use [Stacks.js](https://docs.stacks.co/build-apps/references/libraries/stacks.js) or Clarinet's REPL to interact with functions such as:

```clojure
(register-new-asset "Asset A" u100 "Long form descriptor" (list "tag1" "tag2"))
```

---

## 📘 Example Use Case

Imagine a digital art registry where each artwork (NFT or physical twin) is registered with detailed metadata and tracked over time:

1. **Artists register their works** as assets, becoming custodians.
2. **Galleries or appraisers** are granted third-party read access to validate provenance.
3. **Ownership can be transferred** securely and atomically on-chain.
4. **Regulatory bodies or DAO governance** can use admin authority to freeze assets if needed.

---

## 🧪 Test Coverage

BitVault has been designed with testability in mind. Unit and integration test examples can be written using [Clarinet](https://docs.hiro.so/clarinet/overview) to simulate:

* Registration flows
* Access management
* Unauthorized update attempts
* Validation queries

---

## 📄 License

MIT License — open for use and modification in public or enterprise-grade Stacks projects.

---

## 🤝 Contributing

Pull requests and security audits are welcome. For large changes, please open an issue first to discuss proposed modifications.
