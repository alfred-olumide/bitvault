;; Title: BitVault - Sovereign Asset Registry
;; 
;; Summary:
;; A decentralized custody and provenance tracking system built on Bitcoin's Layer 2,
;; enabling verifiable ownership chains and granular access control for digital assets.
;;
;; Description:
;; BitVault establishes an immutable registry for digital asset management with Bitcoin-grade
;; security. Asset custodians maintain sovereign control while selectively granting verification
;; rights to third parties. Every registration, transfer, and modification is permanently recorded
;; on-chain, creating an auditable provenance trail. The system enforces strict validation rules,
;; ensures atomic custody transfers, and provides cryptographic proof of ownership history-all
;; anchored to Bitcoin's security model through Stacks consensus.

;; CONSTANTS & STATE

;; Global registry sequence counter
(define-data-var registry-sequence uint u0)

;; System administrator authority
(define-constant admin-authority tx-sender)

;; Error codes
(define-constant err-not-found (err u401))
(define-constant err-duplicate (err u402))
(define-constant err-unauthorized (err u403))
(define-constant err-invalid-descriptor (err u404))
(define-constant err-invalid-volume (err u405))
(define-constant err-permission-denied (err u406))
(define-constant err-invalid-operation (err u407))
(define-constant err-access-restricted (err u408))
(define-constant err-invalid-tags (err u409))

;; DATA MAPS

;; Primary asset catalog storage
(define-map asset-catalog
  { asset-sequence: uint }
  {
    asset-descriptor: (string-ascii 64),
    asset-custodian: principal,
    asset-volume: uint,
    registration-block: uint,
    asset-descriptor-extended: (string-ascii 128),
    classification-tags: (list 10 (string-ascii 32))
  }
)

;; Access authorization matrix
(define-map authorization-matrix
  { asset-sequence: uint, authorized-party: principal }
  { access-status: bool }
)

;; PRIVATE HELPER FUNCTIONS

(define-private (asset-is-registered (asset-sequence uint))
  (is-some (map-get? asset-catalog { asset-sequence: asset-sequence }))
)

(define-private (is-custodian-of (asset-sequence uint) (evaluating-party principal))
  (match (map-get? asset-catalog { asset-sequence: asset-sequence })
    catalog-entry (is-eq (get asset-custodian catalog-entry) evaluating-party)
    false
  )
)

(define-private (get-registered-volume (asset-sequence uint))
  (default-to u0
    (get asset-volume
      (map-get? asset-catalog { asset-sequence: asset-sequence })
    )
  )
)

(define-private (is-valid-classification-tag (tag (string-ascii 32)))
  (and
    (> (len tag) u0)
    (< (len tag) u33)
  )
)

(define-private (validate-tag-collection (tags (list 10 (string-ascii 32))))
  (and
    (> (len tags) u0)
    (<= (len tags) u10)
    (is-eq (len (filter is-valid-classification-tag tags)) (len tags))
  )
)

;; CORE REGISTRY OPERATIONS

;; Register a new digital asset with complete metadata
(define-public (register-new-asset 
  (descriptor (string-ascii 64)) 
  (volume uint) 
  (extended-information (string-ascii 128)) 
  (tags (list 10 (string-ascii 32)))
)
  (let
    (
      (next-sequence (+ (var-get registry-sequence) u1))
    )
    ;; Input validation checks
    (asserts! (> (len descriptor) u0) err-invalid-descriptor)
    (asserts! (< (len descriptor) u65) err-invalid-descriptor)
    (asserts! (> volume u0) err-invalid-volume)
    (asserts! (< volume u1000000000) err-invalid-volume)
    (asserts! (> (len extended-information) u0) err-invalid-descriptor)
    (asserts! (< (len extended-information) u129) err-invalid-descriptor)
    (asserts! (validate-tag-collection tags) err-invalid-tags)

    ;; Create catalog entry
    (map-insert asset-catalog
      { asset-sequence: next-sequence }
      {
        asset-descriptor: descriptor,
        asset-custodian: tx-sender,
        asset-volume: volume,
        registration-block: stacks-block-height,
        asset-descriptor-extended: extended-information,
        classification-tags: tags
      }
    )

    ;; Initialize custodian authorization
    (map-insert authorization-matrix
      { asset-sequence: next-sequence, authorized-party: tx-sender }
      { access-status: true }
    )

    ;; Update sequence counter
    (var-set registry-sequence next-sequence)
    (ok next-sequence)
  )
)

;; Update existing asset registration information
(define-public (update-asset-registration 
  (asset-sequence uint) 
  (revised-descriptor (string-ascii 64)) 
  (revised-volume uint) 
  (revised-information (string-ascii 128)) 
  (revised-tags (list 10 (string-ascii 32)))
)
  (let
    (
      (catalog-entry (unwrap! (map-get? asset-catalog { asset-sequence: asset-sequence }) err-not-found))
    )
    ;; Verify asset exists and requestor is the custodian
    (asserts! (asset-is-registered asset-sequence) err-not-found)
    (asserts! (is-eq (get asset-custodian catalog-entry) tx-sender) err-permission-denied)

    ;; Validate updated information
    (asserts! (> (len revised-descriptor) u0) err-invalid-descriptor)
    (asserts! (< (len revised-descriptor) u65) err-invalid-descriptor)
    (asserts! (> revised-volume u0) err-invalid-volume)
    (asserts! (< revised-volume u1000000000) err-invalid-volume)
    (asserts! (> (len revised-information) u0) err-invalid-descriptor)
    (asserts! (< (len revised-information) u129) err-invalid-descriptor)
    (asserts! (validate-tag-collection revised-tags) err-invalid-tags)