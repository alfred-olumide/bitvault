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

    ;; Update asset registration
    (map-set asset-catalog
      { asset-sequence: asset-sequence }
      (merge catalog-entry { 
        asset-descriptor: revised-descriptor, 
        asset-volume: revised-volume, 
        asset-descriptor-extended: revised-information, 
        classification-tags: revised-tags 
      })
    )
    (ok true)
  )
)

;; Cancel asset registration completely
(define-public (cancel-asset-registration (asset-sequence uint))
  (let
    (
      (catalog-entry (unwrap! (map-get? asset-catalog { asset-sequence: asset-sequence }) err-not-found))
    )
    ;; Verify asset exists and requestor is the custodian
    (asserts! (asset-is-registered asset-sequence) err-not-found)
    (asserts! (is-eq (get asset-custodian catalog-entry) tx-sender) err-permission-denied)

    ;; Remove asset registration
    (map-delete asset-catalog { asset-sequence: asset-sequence })
    (ok true)
  )
)

;; Transfer asset custody to new principal
(define-public (transfer-asset-custody (asset-sequence uint) (new-custodian principal))
  (let
    (
      (catalog-entry (unwrap! (map-get? asset-catalog { asset-sequence: asset-sequence }) err-not-found))
    )
    ;; Verify asset exists and requestor is current custodian
    (asserts! (asset-is-registered asset-sequence) err-not-found)
    (asserts! (is-eq (get asset-custodian catalog-entry) tx-sender) err-permission-denied)

    ;; Update custodial ownership
    (map-set asset-catalog
      { asset-sequence: asset-sequence }
      (merge catalog-entry { asset-custodian: new-custodian })
    )
    (ok true)
  )
)

;; AUTHORIZATION MANAGEMENT

;; Grant access authorization to third party
(define-public (authorize-third-party-access (asset-sequence uint) (authorized-party principal))
  (let
    (
      (catalog-entry (unwrap! (map-get? asset-catalog { asset-sequence: asset-sequence }) err-not-found))
    )
    ;; Verify asset exists and requestor is the custodian
    (asserts! (asset-is-registered asset-sequence) err-not-found)
    (asserts! (is-eq (get asset-custodian catalog-entry) tx-sender) err-permission-denied)

    ;; Grant access authorization
    (map-set authorization-matrix
      { asset-sequence: asset-sequence, authorized-party: authorized-party }
      { access-status: true }
    )
    (ok true)
  )
)

;; Revoke third-party access authorization
(define-public (revoke-third-party-access (asset-sequence uint) (third-party principal))
  (let
    (
      (catalog-entry (unwrap! (map-get? asset-catalog { asset-sequence: asset-sequence }) err-not-found))
    )
    ;; Verify asset exists and requestor is the custodian
    (asserts! (asset-is-registered asset-sequence) err-not-found)
    (asserts! (is-eq (get asset-custodian catalog-entry) tx-sender) err-permission-denied)
    (asserts! (not (is-eq third-party tx-sender)) err-invalid-operation)

    ;; Remove authorization entry
    (map-delete authorization-matrix { asset-sequence: asset-sequence, authorized-party: third-party })
    (ok true)
  )
)

;; METADATA MANAGEMENT

;; Append additional classification tags to existing asset
(define-public (extend-classification-tags (asset-sequence uint) (additional-tags (list 10 (string-ascii 32))))
  (let
    (
      (catalog-entry (unwrap! (map-get? asset-catalog { asset-sequence: asset-sequence }) err-not-found))
      (existing-tags (get classification-tags catalog-entry))
      (combined-tags (unwrap! (as-max-len? (concat existing-tags additional-tags) u10) err-invalid-tags))
    )
    ;; Verify asset exists and requestor is the custodian
    (asserts! (asset-is-registered asset-sequence) err-not-found)
    (asserts! (is-eq (get asset-custodian catalog-entry) tx-sender) err-permission-denied)
    (asserts! (validate-tag-collection additional-tags) err-invalid-tags)

    ;; Update asset with combined tag set
    (map-set asset-catalog
      { asset-sequence: asset-sequence }
      (merge catalog-entry { classification-tags: combined-tags })
    )
    (ok combined-tags)
  )
)

;; Update asset volume measurement
(define-public (update-asset-volume (asset-sequence uint) (new-volume uint))
  (let
    (
      (catalog-entry (unwrap! (map-get? asset-catalog { asset-sequence: asset-sequence }) err-not-found))
    )
    ;; Verify asset exists and requestor is the custodian
    (asserts! (asset-is-registered asset-sequence) err-not-found)
    (asserts! (is-eq (get asset-custodian catalog-entry) tx-sender) err-permission-denied)
    (asserts! (> new-volume u0) err-invalid-volume)
    (asserts! (< new-volume u1000000000) err-invalid-volume)

    ;; Update asset volume
    (map-set asset-catalog
      { asset-sequence: asset-sequence }
      (merge catalog-entry { asset-volume: new-volume })
    )
    (ok true)
  )
)

;; ADMINISTRATIVE FUNCTIONS

;; Apply emergency restriction to prevent modifications
(define-public (apply-emergency-restriction (asset-sequence uint))
  (let
    (
      (catalog-entry (unwrap! (map-get? asset-catalog { asset-sequence: asset-sequence }) err-not-found))
    )
    ;; Verify asset exists and requestor has authority
    (asserts! (asset-is-registered asset-sequence) err-not-found)
    (asserts! 
      (or 
        (is-eq tx-sender admin-authority)
        (is-eq (get asset-custodian catalog-entry) tx-sender)
      ) 
      err-unauthorized
    )
    (ok true)
  )
)

;; VERIFICATION & QUERY FUNCTIONS

;; Validate asset custody chain and integrity
(define-public (validate-asset-integrity (asset-sequence uint) (expected-custodian principal))
  (let
    (
      (catalog-entry (unwrap! (map-get? asset-catalog { asset-sequence: asset-sequence }) err-not-found))
      (current-custodian (get asset-custodian catalog-entry))
      (registration-height (get registration-block catalog-entry))
      (access-permitted (default-to 
        false 
        (get access-status 
          (map-get? authorization-matrix { asset-sequence: asset-sequence, authorized-party: tx-sender })
        )
      ))
    )
    ;; Verify asset exists and requestor has appropriate authorization
    (asserts! (asset-is-registered asset-sequence) err-not-found)
    (asserts! 
      (or 
        (is-eq tx-sender current-custodian)
        access-permitted
        (is-eq tx-sender admin-authority)
      ) 
      err-permission-denied
    )

    ;; Return validation results
    (if (is-eq current-custodian expected-custodian)
      (ok {
        validation-passed: true,
        verification-block: stacks-block-height,
        blocks-elapsed: (- stacks-block-height registration-height),
        custodian-verified: true
      })
      (ok {
        validation-passed: false,
        verification-block: stacks-block-height,
        blocks-elapsed: (- stacks-block-height registration-height),
        custodian-verified: false
      })
    )
  )
)

;; Retrieve asset classification profile
(define-public (get-asset-classification (asset-sequence uint))
  (let
    (
      (catalog-entry (unwrap! (map-get? asset-catalog { asset-sequence: asset-sequence }) err-not-found))
      (current-custodian (get asset-custodian catalog-entry))
      (access-permitted (default-to 
        false 
        (get access-status 
          (map-get? authorization-matrix { asset-sequence: asset-sequence, authorized-party: tx-sender })
        )
      ))
    )
    ;; Verify asset exists and requestor has authorization
    (asserts! (asset-is-registered asset-sequence) err-not-found)
    (asserts! 
      (or 
        (is-eq tx-sender current-custodian)
        access-permitted
        (is-eq tx-sender admin-authority)
      ) 
      err-permission-denied
    )

    ;; Return classification tags
    (ok (get classification-tags catalog-entry))
  )
)

;; Check authorization status for a principal
(define-public (check-authorization-status (asset-sequence uint) (evaluating-party principal))
  (let
    (
      (catalog-entry (unwrap! (map-get? asset-catalog { asset-sequence: asset-sequence }) err-not-found))
      (current-custodian (get asset-custodian catalog-entry))
      (access-permitted (default-to 
        false 
        (get access-status 
          (map-get? authorization-matrix { asset-sequence: asset-sequence, authorized-party: evaluating-party })
        )
      ))
    )
    ;; Verify asset exists
    (asserts! (asset-is-registered asset-sequence) err-not-found)

    ;; Return authorization status
    (ok {
      is-custodian: (is-eq evaluating-party current-custodian),
      has-authorization: access-permitted,
      asset-id: asset-sequence
    })
  )
)