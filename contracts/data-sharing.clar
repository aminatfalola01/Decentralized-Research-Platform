;; Data Sharing Agreement Contract
;; Enables secure research collaboration and data sharing

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-AGREEMENT-NOT-FOUND (err u301))
(define-constant ERR-ACCESS-EXPIRED (err u302))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u303))
(define-constant ERR-AGREEMENT-INACTIVE (err u304))
(define-constant ERR-INVALID-INPUT (err u305))
(define-constant ERR-ALREADY-EXISTS (err u306))

;; Data Variables
(define-data-var next-agreement-id uint u1)
(define-data-var platform-fee-rate uint u500) ;; 5% in basis points

;; Data Maps
(define-map data-agreements uint {
  data-provider: principal,
  data-consumer: principal,
  data-identifier: (string-ascii 100),
  access-duration: uint,
  compensation: uint,
  creation-date: uint,
  expiry-date: uint,
  status: (string-ascii 20),
  usage-count: uint,
  max-usage: uint
})

(define-map data-access-logs {agreement-id: uint, access-id: uint} {
  accessor: principal,
  access-date: uint,
  access-type: (string-ascii 50),
  data-hash: (string-ascii 64)
})

(define-map provider-profiles principal {
  total-agreements: uint,
  total-earnings: uint,
  reputation-score: uint,
  data-categories: (list 10 (string-ascii 50)),
  active: bool
})

(define-map consumer-profiles principal {
  total-agreements: uint,
  total-spent: uint,
  reputation-score: uint,
  research-areas: (list 10 (string-ascii 50)),
  active: bool
})

(define-map agreement-reviews {agreement-id: uint, reviewer: principal} {
  rating: uint,
  comments: (string-ascii 300),
  review-date: uint
})

;; Read-only functions
(define-read-only (get-agreement (agreement-id uint))
  (map-get? data-agreements agreement-id)
)

(define-read-only (get-provider-profile (provider principal))
  (map-get? provider-profiles provider)
)

(define-read-only (get-consumer-profile (consumer principal))
  (map-get? consumer-profiles consumer)
)

(define-read-only (get-access-log (agreement-id uint) (access-id uint))
  (map-get? data-access-logs {agreement-id: agreement-id, access-id: access-id})
)

(define-read-only (get-next-agreement-id)
  (var-get next-agreement-id)
)

(define-read-only (check-access-validity (agreement-id uint) (accessor principal))
  (match (map-get? data-agreements agreement-id)
    agreement (and
      (is-eq (get data-consumer agreement) accessor)
      (is-eq (get status agreement) "active")
      (< block-height (get expiry-date agreement))
      (< (get usage-count agreement) (get max-usage agreement))
    )
    false
  )
)

;; Public functions
(define-public (register-data-provider (data-categories (list 10 (string-ascii 50))))
  (begin
    (asserts! (> (len data-categories) u0) ERR-INVALID-INPUT)
    (asserts! (<= (len data-categories) u10) ERR-INVALID-INPUT)

    (map-set provider-profiles tx-sender {
      total-agreements: u0,
      total-earnings: u0,
      reputation-score: u100,
      data-categories: data-categories,
      active: true
    })

    (ok true)
  )
)

(define-public (register-data-consumer (research-areas (list 10 (string-ascii 50))))
  (begin
    (asserts! (> (len research-areas) u0) ERR-INVALID-INPUT)
    (asserts! (<= (len research-areas) u10) ERR-INVALID-INPUT)

    (map-set consumer-profiles tx-sender {
      total-agreements: u0,
      total-spent: u0,
      reputation-score: u100,
      research-areas: research-areas,
      active: true
    })

    (ok true)
  )
)

(define-public (create-data-agreement (consumer principal) (data-identifier (string-ascii 100)) (access-duration uint) (compensation uint) (max-usage uint))
  (let ((agreement-id (var-get next-agreement-id))
        (expiry-date (+ block-height access-duration))
        (provider-profile (unwrap! (map-get? provider-profiles tx-sender) ERR-NOT-AUTHORIZED))
        (consumer-profile (unwrap! (map-get? consumer-profiles consumer) ERR-NOT-AUTHORIZED)))

    (asserts! (get active provider-profile) ERR-NOT-AUTHORIZED)
    (asserts! (get active consumer-profile) ERR-NOT-AUTHORIZED)
    (asserts! (> access-duration u0) ERR-INVALID-INPUT)
    (asserts! (> compensation u0) ERR-INVALID-INPUT)
    (asserts! (> max-usage u0) ERR-INVALID-INPUT)
    (asserts! (> (len data-identifier) u0) ERR-INVALID-INPUT)
    (asserts! (< (len data-identifier) u101) ERR-INVALID-INPUT)

    (map-set data-agreements agreement-id {
      data-provider: tx-sender,
      data-consumer: consumer,
      data-identifier: data-identifier,
      access-duration: access-duration,
      compensation: compensation,
      creation-date: block-height,
      expiry-date: expiry-date,
      status: "pending",
      usage-count: u0,
      max-usage: max-usage
    })

    (var-set next-agreement-id (+ agreement-id u1))
    (ok agreement-id)
  )
)

(define-public (accept-agreement (agreement-id uint))
  (let ((agreement (unwrap! (map-get? data-agreements agreement-id) ERR-AGREEMENT-NOT-FOUND))
        (platform-fee (/ (* (get compensation agreement) (var-get platform-fee-rate)) u10000))
        (provider-payment (- (get compensation agreement) platform-fee)))

    (asserts! (is-eq tx-sender (get data-consumer agreement)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status agreement) "pending") ERR-AGREEMENT-INACTIVE)

    ;; Transfer payment
    (try! (stx-transfer? (get compensation agreement) tx-sender (as-contract tx-sender)))

    ;; Pay provider (minus platform fee)
    (try! (as-contract (stx-transfer? provider-payment tx-sender (get data-provider agreement))))

    ;; Update agreement status
    (map-set data-agreements agreement-id (merge agreement {status: "active"}))

    ;; Update profiles
    (let ((provider-profile (unwrap! (map-get? provider-profiles (get data-provider agreement)) ERR-NOT-AUTHORIZED))
          (consumer-profile (unwrap! (map-get? consumer-profiles tx-sender) ERR-NOT-AUTHORIZED)))

      (map-set provider-profiles (get data-provider agreement)
        (merge provider-profile {
          total-agreements: (+ (get total-agreements provider-profile) u1),
          total-earnings: (+ (get total-earnings provider-profile) provider-payment)
        }))

      (map-set consumer-profiles tx-sender
        (merge consumer-profile {
          total-agreements: (+ (get total-agreements consumer-profile) u1),
          total-spent: (+ (get total-spent consumer-profile) (get compensation agreement))
        }))
    )

    (ok true)
  )
)

(define-public (access-data (agreement-id uint) (access-type (string-ascii 50)) (data-hash (string-ascii 64)))
  (let ((agreement (unwrap! (map-get? data-agreements agreement-id) ERR-AGREEMENT-NOT-FOUND)))

    (asserts! (check-access-validity agreement-id tx-sender) ERR-ACCESS-EXPIRED)
    (asserts! (> (len access-type) u0) ERR-INVALID-INPUT)
    (asserts! (< (len access-type) u51) ERR-INVALID-INPUT)
    (asserts! (is-eq (len data-hash) u64) ERR-INVALID-INPUT)

    ;; Log access
    (let ((new-usage-count (+ (get usage-count agreement) u1)))
      (map-set data-access-logs {agreement-id: agreement-id, access-id: new-usage-count} {
        accessor: tx-sender,
        access-date: block-height,
        access-type: access-type,
        data-hash: data-hash
      })

      ;; Update usage count
      (map-set data-agreements agreement-id (merge agreement {usage-count: new-usage-count}))
    )

    (ok true)
  )
)

(define-public (extend-agreement (agreement-id uint) (additional-duration uint) (additional-compensation uint))
  (let ((agreement (unwrap! (map-get? data-agreements agreement-id) ERR-AGREEMENT-NOT-FOUND)))

    (asserts! (is-eq tx-sender (get data-consumer agreement)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status agreement) "active") ERR-AGREEMENT-INACTIVE)
    (asserts! (> additional-duration u0) ERR-INVALID-INPUT)
    (asserts! (> additional-compensation u0) ERR-INVALID-INPUT)

    ;; Transfer additional payment
    (let ((platform-fee (/ (* additional-compensation (var-get platform-fee-rate)) u10000))
          (provider-payment (- additional-compensation platform-fee)))

      (try! (stx-transfer? additional-compensation tx-sender (as-contract tx-sender)))
      (try! (as-contract (stx-transfer? provider-payment tx-sender (get data-provider agreement))))

      ;; Update agreement
      (map-set data-agreements agreement-id (merge agreement {
        expiry-date: (+ (get expiry-date agreement) additional-duration),
        compensation: (+ (get compensation agreement) additional-compensation)
      }))
    )

    (ok true)
  )
)

(define-public (terminate-agreement (agreement-id uint))
  (let ((agreement (unwrap! (map-get? data-agreements agreement-id) ERR-AGREEMENT-NOT-FOUND)))

    (asserts! (or
      (is-eq tx-sender (get data-provider agreement))
      (is-eq tx-sender (get data-consumer agreement))
    ) ERR-NOT-AUTHORIZED)

    (map-set data-agreements agreement-id (merge agreement {status: "terminated"}))
    (ok true)
  )
)

(define-public (review-agreement (agreement-id uint) (rating uint) (comments (string-ascii 300)))
  (let ((agreement (unwrap! (map-get? data-agreements agreement-id) ERR-AGREEMENT-NOT-FOUND)))

    (asserts! (or
      (is-eq tx-sender (get data-provider agreement))
      (is-eq tx-sender (get data-consumer agreement))
    ) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-INPUT)
    (asserts! (< (len comments) u301) ERR-INVALID-INPUT)

    (map-set agreement-reviews {agreement-id: agreement-id, reviewer: tx-sender} {
      rating: rating,
      comments: comments,
      review-date: block-height
    })

    (ok true)
  )
)

(define-public (update-platform-fee (new-fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-rate u1000) ERR-INVALID-INPUT) ;; Max 10%

    (var-set platform-fee-rate new-fee-rate)
    (ok true)
  )
)
