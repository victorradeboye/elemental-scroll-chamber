;; elemental-scroll-chamber
;; ===============================================
;; OPERATIONAL ERROR CODES
;; ===============================================

;; System response indicators for transaction outcomes
(define-constant unauthorized-nexus-access (err u300))
(define-constant document-not-found-error (err u301))
(define-constant duplicate-entry-violation (err u302))
(define-constant invalid-title-format (err u303))
(define-constant page-count-boundary-error (err u304))
(define-constant custody-authority-mismatch (err u305))
(define-constant permission-denied-fault (err u306))
(define-constant authentication-failed-state (err u307))
(define-constant metadata-validation-failure (err u308))

;; Primary authority principal for nexus governance
(define-constant nexus-supreme-controller tx-sender)

;; ===============================================
;; DOCUMENT TRACKING VARIABLES
;; ===============================================

;; Global sequence generator for document identification
(define-data-var global-document-sequence uint u0)

;; ===============================================
;; CORE DATA MAPPING STRUCTURES
;; ===============================================

;; Master registry for quantum manuscript records
(define-map quantum-document-registry
  { document-sequence-id: uint }
  {
    document-title-text: (string-ascii 64),
    current-custodian: principal,
    total-page-count: uint,
    creation-block-timestamp: uint,
    origin-description: (string-ascii 128),
    category-tags: (list 10 (string-ascii 32))
  }
)

;; Access control matrix for research permissions
(define-map research-access-matrix
  { document-sequence-id: uint, researcher-principal: principal }
  { access-granted-flag: bool }
)

;; ===============================================
;; INTERNAL VALIDATION FUNCTIONS
;; ===============================================

;; Verifies document existence in quantum registry
(define-private (document-exists-in-nexus? (sequence-id uint))
  (is-some (map-get? quantum-document-registry { document-sequence-id: sequence-id }))
)

;; Validates custodian authorization for document operations
(define-private (verify-custodian-authority? (sequence-id uint) (claiming-principal principal))
  (match (map-get? quantum-document-registry { document-sequence-id: sequence-id })
    document-record (is-eq (get current-custodian document-record) claiming-principal)
    false
  )
)

;; Retrieves total page count for specified document
(define-private (extract-document-page-count (sequence-id uint))
  (default-to u0
    (get total-page-count
      (map-get? quantum-document-registry { document-sequence-id: sequence-id })
    )
  )
)

;; Validates category tag format compliance
(define-private (validate-tag-format (tag-string (string-ascii 32)))
  (and
    (> (len tag-string) u0)
    (< (len tag-string) u33)
  )
)

;; Ensures category tag list integrity
(define-private (validate-tag-collection (tag-list (list 10 (string-ascii 32))))
  (and
    (> (len tag-list) u0)
    (<= (len tag-list) u10)
    (is-eq (len (filter validate-tag-format tag-list)) (len tag-list))
  )
)

;; ===============================================
;; DOCUMENT LIFECYCLE MANAGEMENT
;; ===============================================

;; Registers new document in quantum manuscript nexus
(define-public (register-quantum-document 
  (title-text (string-ascii 64)) 
  (page-count uint) 
  (origin-info (string-ascii 128)) 
  (category-tags (list 10 (string-ascii 32)))
)
  (let
    (
      (next-sequence-id (+ (var-get global-document-sequence) u1))
    )
    ;; Comprehensive input validation checks
    (asserts! (> (len title-text) u0) invalid-title-format)
    (asserts! (< (len title-text) u65) invalid-title-format)
    (asserts! (> page-count u0) page-count-boundary-error)
    (asserts! (< page-count u1000000000) page-count-boundary-error)
    (asserts! (> (len origin-info) u0) invalid-title-format)
    (asserts! (< (len origin-info) u129) invalid-title-format)
    (asserts! (validate-tag-collection category-tags) metadata-validation-failure)

    ;; Create document record in quantum registry
    (map-insert quantum-document-registry
      { document-sequence-id: next-sequence-id }
      {
        document-title-text: title-text,
        current-custodian: tx-sender,
        total-page-count: page-count,
        creation-block-timestamp: block-height,
        origin-description: origin-info,
        category-tags: category-tags
      }
    )

    ;; Grant initial research access to creator
    (map-insert research-access-matrix
      { document-sequence-id: next-sequence-id, researcher-principal: tx-sender }
      { access-granted-flag: true }
    )

    ;; Update global sequence counter
    (var-set global-document-sequence next-sequence-id)
    (ok next-sequence-id)
  )
)

;; ===============================================
;; DOCUMENT MODIFICATION OPERATIONS
;; ===============================================

;; Updates document metadata after validation
(define-public (modify-document-metadata 
  (sequence-id uint) 
  (updated-title (string-ascii 64)) 
  (updated-page-count uint) 
  (updated-origin (string-ascii 128)) 
  (updated-tags (list 10 (string-ascii 32)))
)
  (let
    (
      (document-record (unwrap! (map-get? quantum-document-registry { document-sequence-id: sequence-id }) document-not-found-error))
    )
    ;; Verify document existence and custodian authority
    (asserts! (document-exists-in-nexus? sequence-id) document-not-found-error)
    (asserts! (is-eq (get current-custodian document-record) tx-sender) custody-authority-mismatch)

    ;; Validate updated metadata parameters
    (asserts! (> (len updated-title) u0) invalid-title-format)
    (asserts! (< (len updated-title) u65) invalid-title-format)
    (asserts! (> updated-page-count u0) page-count-boundary-error)
    (asserts! (< updated-page-count u1000000000) page-count-boundary-error)
    (asserts! (> (len updated-origin) u0) invalid-title-format)
    (asserts! (< (len updated-origin) u129) invalid-title-format)
    (asserts! (validate-tag-collection updated-tags) metadata-validation-failure)

    ;; Apply metadata updates to registry
    (map-set quantum-document-registry
      { document-sequence-id: sequence-id }
      (merge document-record { 
        document-title-text: updated-title, 
        total-page-count: updated-page-count, 
        origin-description: updated-origin, 
        category-tags: updated-tags 
      })
    )
    (ok true)
  )
)

;; Transfers document custody to new custodian
(define-public (transfer-document-custody (sequence-id uint) (new-custodian principal))
  (let
    (
      (document-record (unwrap! (map-get? quantum-document-registry { document-sequence-id: sequence-id }) document-not-found-error))
    )
    ;; Validate document existence and current custodian authority
    (asserts! (document-exists-in-nexus? sequence-id) document-not-found-error)
    (asserts! (is-eq (get current-custodian document-record) tx-sender) custody-authority-mismatch)

    ;; Execute custody transfer operation
    (map-set quantum-document-registry
      { document-sequence-id: sequence-id }
      (merge document-record { current-custodian: new-custodian })
    )
    (ok true)
  )
)

;; ===============================================
;; ACCESS CONTROL MECHANISMS
;; ===============================================

;; Revokes research access for specified researcher
(define-public (revoke-research-access (sequence-id uint) (researcher-principal principal))
  (let
    (
      (document-record (unwrap! (map-get? quantum-document-registry { document-sequence-id: sequence-id }) document-not-found-error))
    )
    ;; Validate document existence and custodian authority
    (asserts! (document-exists-in-nexus? sequence-id) document-not-found-error)
    (asserts! (is-eq (get current-custodian document-record) tx-sender) custody-authority-mismatch)
    (asserts! (not (is-eq researcher-principal tx-sender)) unauthorized-nexus-access)

    ;; Remove research access permission
    (map-delete research-access-matrix { document-sequence-id: sequence-id, researcher-principal: researcher-principal })
    (ok true)
  )
)

;; ===============================================
;; DOCUMENT ARCHIVAL OPERATIONS
;; ===============================================

;; Permanently removes document from active nexus
(define-public (archive-quantum-document (sequence-id uint))
  (let
    (
      (document-record (unwrap! (map-get? quantum-document-registry { document-sequence-id: sequence-id }) document-not-found-error))
    )
    ;; Validate document existence and custodian authority
    (asserts! (document-exists-in-nexus? sequence-id) document-not-found-error)
    (asserts! (is-eq (get current-custodian document-record) tx-sender) custody-authority-mismatch)

    ;; Remove document from quantum registry
    (map-delete quantum-document-registry { document-sequence-id: sequence-id })
    (ok true)
  )
)

;; ===============================================
;; METADATA ENHANCEMENT FEATURES
;; ===============================================

;; Expands category tag collection for document
(define-public (expand-category-tags (sequence-id uint) (additional-tags (list 10 (string-ascii 32))))
  (let
    (
      (document-record (unwrap! (map-get? quantum-document-registry { document-sequence-id: sequence-id }) document-not-found-error))
      (current-tags (get category-tags document-record))
      (merged-tags (unwrap! (as-max-len? (concat current-tags additional-tags) u10) metadata-validation-failure))
    )
    ;; Validate document existence and custodian authority
    (asserts! (document-exists-in-nexus? sequence-id) document-not-found-error)
    (asserts! (is-eq (get current-custodian document-record) tx-sender) custody-authority-mismatch)

    ;; Validate additional tag collection
    (asserts! (validate-tag-collection additional-tags) metadata-validation-failure)

    ;; Update document with expanded tag collection
    (map-set quantum-document-registry
      { document-sequence-id: sequence-id }
      (merge document-record { category-tags: merged-tags })
    )
    (ok merged-tags)
  )
)

;; Applies preservation status to document
(define-public (apply-preservation-status (sequence-id uint))
  (let
    (
      (document-record (unwrap! (map-get? quantum-document-registry { document-sequence-id: sequence-id }) document-not-found-error))
      (preservation-tag "PRESERVATION-STATUS")
      (current-tags (get category-tags document-record))
    )
    ;; Validate document existence and authorized access
    (asserts! (document-exists-in-nexus? sequence-id) document-not-found-error)
    (asserts! 
      (or 
        (is-eq tx-sender nexus-supreme-controller)
        (is-eq (get current-custodian document-record) tx-sender)
      ) 
      unauthorized-nexus-access
    )

    (ok true)
  )
)

;; ===============================================
;; DOCUMENT VERIFICATION SYSTEM
;; ===============================================

;; Performs comprehensive document authentication verification
(define-public (authenticate-document-record (sequence-id uint) (expected-custodian principal))
  (let
    (
      (document-record (unwrap! (map-get? quantum-document-registry { document-sequence-id: sequence-id }) document-not-found-error))
      (actual-custodian (get current-custodian document-record))
      (creation-timestamp (get creation-block-timestamp document-record))
      (has-research-access (default-to 
        false 
        (get access-granted-flag 
          (map-get? research-access-matrix { document-sequence-id: sequence-id, researcher-principal: tx-sender })
        )
      ))
    )
    ;; Validate document existence and researcher authority
    (asserts! (document-exists-in-nexus? sequence-id) document-not-found-error)
    (asserts! 
      (or 
        (is-eq tx-sender actual-custodian)
        has-research-access
        (is-eq tx-sender nexus-supreme-controller)
      ) 
      permission-denied-fault
    )

    ;; Generate comprehensive authentication response
    (if (is-eq actual-custodian expected-custodian)
      ;; Return successful authentication with temporal data
      (ok {
        authentication-success: true,
        current-block-height: block-height,
        document-age: (- block-height creation-timestamp),
        custodian-verified: true
      })
      ;; Return custodian verification failure
      (ok {
        authentication-success: false,
        current-block-height: block-height,
        document-age: (- block-height creation-timestamp),
        custodian-verified: false
      })
    )
  )
)

