;; Crowdfunding DApp Smart Contract
;; A decentralized crowdfunding platform with deadline-based funding and automatic refunds

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-deadline-passed (err u103))
(define-constant err-funding-active (err u104))
(define-constant err-funding-failed (err u105))
(define-constant err-funding-successful (err u106))
(define-constant err-no-contribution (err u107))
(define-constant err-insufficient-funds (err u108))
(define-constant err-deadline-not-passed (err u109))

;; Data Variables
(define-data-var next-campaign-id uint u1)

;; Campaign Status
(define-constant status-active u1)
(define-constant status-successful u2)
(define-constant status-failed u3)

;; Data Maps
(define-map campaigns 
  uint 
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    goal: uint,
    deadline: uint,
    raised: uint,
    status: uint,
    created-at: uint
  })

(define-map contributions 
  { campaign-id: uint, contributor: principal } 
  uint)

(define-map campaign-contributors
  uint
  (list 200 principal))

;; Private Functions
(define-private (is-campaign-owner (campaign-id uint) (user principal))
  (match (map-get? campaigns campaign-id)
    campaign (is-eq (get creator campaign) user)
    false))

(define-private (get-block-height-now)
  block-height)

;; Read-only Functions
(define-read-only (get-campaign (campaign-id uint))
  (map-get? campaigns campaign-id))

(define-read-only (get-contribution (campaign-id uint) (contributor principal))
  (default-to u0 (map-get? contributions { campaign-id: campaign-id, contributor: contributor })))

(define-read-only (get-campaign-contributors (campaign-id uint))
  (default-to (list) (map-get? campaign-contributors campaign-id)))

(define-read-only (get-next-campaign-id)
  (var-get next-campaign-id))

;; Public Functions

;; Create a new campaign
(define-public (create-campaign (title (string-ascii 100)) (description (string-ascii 500)) (goal uint) (duration uint))
  (let ((campaign-id (var-get next-campaign-id))
        (deadline (+ (get-block-height-now) duration)))
    (map-set campaigns campaign-id {
      creator: tx-sender,
      title: title,
      description: description,
      goal: goal,
      deadline: deadline,
      raised: u0,
      status: status-active,
      created-at: (get-block-height-now)
    })
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)))

;; Contribute to a campaign
(define-public (contribute (campaign-id uint) (amount uint))
  (match (map-get? campaigns campaign-id)
    campaign 
    (if (> (get-block-height-now) (get deadline campaign))
      err-deadline-passed
      (if (not (is-eq (get status campaign) status-active))
        err-funding-active
        (begin
          ;; Transfer STX from contributor to contract
          (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
          
          ;; Update contribution amount
          (let ((current-contribution (get-contribution campaign-id tx-sender)))
            (map-set contributions 
              { campaign-id: campaign-id, contributor: tx-sender }
              (+ current-contribution amount))
            
            ;; Add contributor to list if first contribution
            (if (is-eq current-contribution u0)
              (let ((contributors (get-campaign-contributors campaign-id)))
                (map-set campaign-contributors campaign-id 
                  (unwrap-panic (as-max-len? (append contributors tx-sender) u200))))
              true)
            
            ;; Update campaign raised amount
            (map-set campaigns campaign-id 
              (merge campaign { raised: (+ (get raised campaign) amount) }))
            
            (ok true)))))
    err-not-found))

;; Finalize campaign (can be called by anyone after deadline)
(define-public (finalize-campaign (campaign-id uint))
  (match (map-get? campaigns campaign-id)
    campaign
    (if (<= (get-block-height-now) (get deadline campaign))
      err-deadline-not-passed
      (if (not (is-eq (get status campaign) status-active))
        err-funding-active
        (let ((new-status (if (>= (get raised campaign) (get goal campaign))
                           status-successful
                           status-failed)))
          (map-set campaigns campaign-id 
            (merge campaign { status: new-status }))
          (ok new-status))))
    err-not-found))

;; Withdraw funds (for successful campaigns, only creator can withdraw)
(define-public (withdraw-funds (campaign-id uint))
  (match (map-get? campaigns campaign-id)
    campaign
    (if (not (is-campaign-owner campaign-id tx-sender))
      err-owner-only
      (if (not (is-eq (get status campaign) status-successful))
        err-funding-successful
        (begin
          ;; Transfer all raised funds to campaign creator
          (try! (as-contract (stx-transfer? (get raised campaign) tx-sender (get creator campaign))))
          (ok true))))
    err-not-found))

;; Request refund (for failed campaigns, contributors can get their money back)
(define-public (request-refund (campaign-id uint))
  (match (map-get? campaigns campaign-id)
    campaign
    (if (not (is-eq (get status campaign) status-failed))
      err-funding-failed
      (let ((contribution-amount (get-contribution campaign-id tx-sender)))
        (if (is-eq contribution-amount u0)
          err-no-contribution
          (begin
            ;; Remove contribution record
            (map-delete contributions { campaign-id: campaign-id, contributor: tx-sender })
            
            ;; Transfer refund to contributor
            (try! (as-contract (stx-transfer? contribution-amount tx-sender tx-sender)))
            (ok contribution-amount)))))
    err-not-found))

;; Emergency function to finalize and process refunds for failed campaigns
(define-public (process-failed-campaign-refunds (campaign-id uint))
  (match (map-get? campaigns campaign-id)
    campaign
    (if (> (get-block-height-now) (get deadline campaign))
      (if (< (get raised campaign) (get goal campaign))
        (begin
          ;; Mark as failed if not already done
          (map-set campaigns campaign-id 
            (merge campaign { status: status-failed }))
          (ok true))
        err-funding-successful)
      err-deadline-not-passed)
    err-not-found))