;; Peer Review Coordination Contract
;; Manages academic paper evaluation and reviewer coordination

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-PAPER-NOT-FOUND (err u201))
(define-constant ERR-REVIEWER-NOT-FOUND (err u202))
(define-constant ERR-REVIEW_DEADLINE_PASSED (err u203))
(define-constant ERR-ALREADY-REVIEWED (err u204))
(define-constant ERR-INVALID-RATING (err u205))
(define-constant ERR-INSUFFICIENT-REVIEWS (err u206))
(define-constant ERR-INVALID-INPUT (err u207))

;; Data Variables
(define-data-var next-paper-id uint u1)
(define-data-var min-reviews-required uint u3)
(define-data-var review-reward uint u10000) ;; 10 STX per review

;; Data Maps
(define-map papers uint {
  author: principal,
  title: (string-ascii 150),
  abstract: (string-ascii 1000),
  field: (string-ascii 50),
  submission-date: uint,
  review-deadline: uint,
  status: (string-ascii 20),
  total-reviews: uint,
  average-score: uint
})

(define-map paper-reviewers {paper-id: uint, reviewer: principal} {
  assigned-date: uint,
  review-submitted: bool,
  score: uint,
  comments: (string-ascii 500),
  recommendation: (string-ascii 20)
})

(define-map reviewer-profiles principal {
  expertise-fields: (list 5 (string-ascii 50)),
  total-reviews: uint,
  average-rating: uint,
  reputation-score: uint,
  active: bool
})

(define-map paper-reviews {paper-id: uint, review-id: uint} {
  reviewer: principal,
  score: uint,
  comments: (string-ascii 500),
  recommendation: (string-ascii 20),
  submission-date: uint
})

;; Read-only functions
(define-read-only (get-paper (paper-id uint))
  (map-get? papers paper-id)
)

(define-read-only (get-reviewer-profile (reviewer principal))
  (map-get? reviewer-profiles reviewer)
)

(define-read-only (get-paper-reviewer (paper-id uint) (reviewer principal))
  (map-get? paper-reviewers {paper-id: paper-id, reviewer: reviewer})
)

(define-read-only (get-next-paper-id)
  (var-get next-paper-id)
)

(define-read-only (get-review-reward)
  (var-get review-reward)
)

;; Public functions
(define-public (register-reviewer (expertise-fields (list 5 (string-ascii 50))))
  (begin
    (asserts! (> (len expertise-fields) u0) ERR-INVALID-INPUT)
    (asserts! (<= (len expertise-fields) u5) ERR-INVALID-INPUT)

    (map-set reviewer-profiles tx-sender {
      expertise-fields: expertise-fields,
      total-reviews: u0,
      average-rating: u0,
      reputation-score: u100,
      active: true
    })

    (ok true)
  )
)

(define-public (submit-paper (title (string-ascii 150)) (abstract (string-ascii 1000)) (field (string-ascii 50)))
  (let ((paper-id (var-get next-paper-id))
        (review-deadline (+ block-height u2016))) ;; ~14 days

    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (< (len title) u151) ERR-INVALID-INPUT)
    (asserts! (> (len abstract) u0) ERR-INVALID-INPUT)
    (asserts! (< (len abstract) u1001) ERR-INVALID-INPUT)
    (asserts! (> (len field) u0) ERR-INVALID-INPUT)
    (asserts! (< (len field) u51) ERR-INVALID-INPUT)

    (map-set papers paper-id {
      author: tx-sender,
      title: title,
      abstract: abstract,
      field: field,
      submission-date: block-height,
      review-deadline: review-deadline,
      status: "under-review",
      total-reviews: u0,
      average-score: u0
    })

    (var-set next-paper-id (+ paper-id u1))
    (ok paper-id)
  )
)

(define-public (assign-reviewer (paper-id uint) (reviewer principal))
  (let ((paper (unwrap! (map-get? papers paper-id) ERR-PAPER-NOT-FOUND))
        (reviewer-profile (unwrap! (map-get? reviewer-profiles reviewer) ERR-REVIEWER-NOT-FOUND)))

    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status paper) "under-review") ERR-REVIEW_DEADLINE_PASSED)
    (asserts! (get active reviewer-profile) ERR-REVIEWER-NOT-FOUND)
    (asserts! (< block-height (get review-deadline paper)) ERR-REVIEW_DEADLINE_PASSED)

    (map-set paper-reviewers {paper-id: paper-id, reviewer: reviewer} {
      assigned-date: block-height,
      review-submitted: false,
      score: u0,
      comments: "",
      recommendation: ""
    })

    (ok true)
  )
)

(define-public (submit-review (paper-id uint) (score uint) (comments (string-ascii 500)) (recommendation (string-ascii 20)))
  (let ((paper (unwrap! (map-get? papers paper-id) ERR-PAPER-NOT-FOUND))
        (reviewer-assignment (unwrap! (map-get? paper-reviewers {paper-id: paper-id, reviewer: tx-sender}) ERR-NOT-AUTHORIZED))
        (reviewer-profile (unwrap! (map-get? reviewer-profiles tx-sender) ERR-REVIEWER-NOT-FOUND)))

    (asserts! (< block-height (get review-deadline paper)) ERR-REVIEW_DEADLINE_PASSED)
    (asserts! (not (get review-submitted reviewer-assignment)) ERR-ALREADY-REVIEWED)
    (asserts! (and (>= score u1) (<= score u10)) ERR-INVALID-RATING)
    (asserts! (< (len comments) u501) ERR-INVALID-INPUT)
    (asserts! (< (len recommendation) u21) ERR-INVALID-INPUT)

    ;; Update reviewer assignment
    (map-set paper-reviewers {paper-id: paper-id, reviewer: tx-sender}
      (merge reviewer-assignment {
        review-submitted: true,
        score: score,
        comments: comments,
        recommendation: recommendation
      }))

    ;; Update paper statistics
    (let ((new-total-reviews (+ (get total-reviews paper) u1))
          (current-total-score (* (get average-score paper) (get total-reviews paper)))
          (new-average-score (/ (+ current-total-score score) new-total-reviews)))

      (map-set papers paper-id (merge paper {
        total-reviews: new-total-reviews,
        average-score: new-average-score
      }))
    )

    ;; Update reviewer profile
    (let ((new-reviewer-total (+ (get total-reviews reviewer-profile) u1)))
      (map-set reviewer-profiles tx-sender (merge reviewer-profile {
        total-reviews: new-reviewer-total
      }))
    )

    ;; Reward reviewer
    (try! (as-contract (stx-transfer? (var-get review-reward) tx-sender tx-sender)))

    (ok true)
  )
)

(define-public (finalize-review-process (paper-id uint))
  (let ((paper (unwrap! (map-get? papers paper-id) ERR-PAPER-NOT-FOUND)))
    (asserts! (>= block-height (get review-deadline paper)) ERR-REVIEW_DEADLINE_PASSED)
    (asserts! (>= (get total-reviews paper) (var-get min-reviews-required)) ERR-INSUFFICIENT-REVIEWS)

    (let ((final-status (if (>= (get average-score paper) u7) "accepted" "rejected")))
      (map-set papers paper-id (merge paper {status: final-status}))
      (ok final-status)
    )
  )
)

(define-public (update-reviewer-reputation (reviewer principal) (new-reputation uint))
  (let ((reviewer-profile (unwrap! (map-get? reviewer-profiles reviewer) ERR-REVIEWER-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-reputation u1000) ERR-INVALID-INPUT)

    (map-set reviewer-profiles reviewer (merge reviewer-profile {
      reputation-score: new-reputation
    }))

    (ok true)
  )
)

(define-public (deactivate-reviewer (reviewer principal))
  (let ((reviewer-profile (unwrap! (map-get? reviewer-profiles reviewer) ERR-REVIEWER-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set reviewer-profiles reviewer (merge reviewer-profile {active: false}))
    (ok true)
  )
)

(define-public (set-review-parameters (min-reviews uint) (reward-amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> min-reviews u0) ERR-INVALID-INPUT)
    (asserts! (> reward-amount u0) ERR-INVALID-INPUT)

    (var-set min-reviews-required min-reviews)
    (var-set review-reward reward-amount)
    (ok true)
  )
)
