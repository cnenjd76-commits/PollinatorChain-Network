;; PollinatorChain-Network: Support Rewards Contract
;; Token-based incentive system for conservation efforts

;; SIP-010 Token Trait
(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri ((optional uint)) (response (optional (string-utf8 256)) uint))
  )
)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u401))
(define-constant err-not-found (err u404))
(define-constant err-invalid-data (err u400))
(define-constant err-insufficient-balance (err u402))
(define-constant err-already-claimed (err u409))
(define-constant token-name "PollinatorChain")
(define-constant token-symbol "PCHN")
(define-constant token-decimals u6)
(define-constant token-uri u"https://pollinatorchain.network/token")
(define-constant max-supply u1000000000000) ;; 1 million tokens with 6 decimals

;; Reward amounts (in micro-tokens)
(define-constant gardening-reward u1000000) ;; 1 PCHN
(define-constant pesticide-reduction-reward u5000000) ;; 5 PCHN
(define-constant citizen-science-reward u500000) ;; 0.5 PCHN
(define-constant habitat-creation-reward u10000000) ;; 10 PCHN
(define-constant research-contribution-reward u2000000) ;; 2 PCHN

;; Data Variables
(define-data-var total-supply uint u0)
(define-data-var next-activity-id uint u1)
(define-data-var total-rewards-distributed uint u0)
(define-data-var active-participants uint u0)

;; Data Maps
(define-map token-balances principal uint)
(define-map token-allowances {owner: principal, spender: principal} uint)

(define-map conservation-activities
  { activity-id: uint }
  {
    participant: principal,
    activity-type: (string-ascii 32),
    description: (string-ascii 256),
    location-lat: int,
    location-lon: int,
    submission-date: uint,
    verification-status: (string-ascii 32),
    verifier: (optional principal),
    reward-amount: uint,
    is-rewarded: bool
  }
)

(define-map gardening-initiatives
  { initiative-id: uint }
  {
    participant: principal,
    plant-species: (string-ascii 64),
    quantity-planted: uint,
    area-size: uint,
    planting-date: uint,
    native-plants-ratio: uint,
    pollinator-friendly-score: uint,
    maintenance-commitment: uint
  }
)

(define-map pesticide-reduction-records
  { record-id: uint }
  {
    participant: principal,
    previous-usage: uint,
    current-usage: uint,
    reduction-percentage: uint,
    area-affected: uint,
    verification-method: (string-ascii 64),
    baseline-date: uint,
    measurement-date: uint
  }
)

(define-map citizen-science-contributions
  { contribution-id: uint }
  {
    participant: principal,
    contribution-type: (string-ascii 64),
    data-quality-score: uint,
    observations-count: uint,
    submission-date: uint,
    research-value: uint,
    peer-review-score: uint
  }
)

(define-map participant-profiles
  { participant: principal }
  {
    total-rewards-earned: uint,
    activities-completed: uint,
    conservation-score: uint,
    registration-date: uint,
    reputation-level: (string-ascii 32),
    specializations: (string-ascii 128)
  }
)

(define-map authorized-verifiers
  { verifier: principal }
  {
    is-authorized: bool,
    verification-authority: (string-ascii 128),
    specialization: (string-ascii 64),
    verifications-completed: uint,
    accuracy-rating: uint
  }
)

(define-map reward-multipliers
  { activity-type: (string-ascii 32) }
  {
    base-multiplier: uint,
    seasonal-bonus: uint,
    quality-bonus: uint,
    community-bonus: uint
  }
)

;; Token Functions (SIP-010 Implementation)

;; Transfer tokens
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (let 
    (
      (sender-balance (get-balance-uint sender))
    )
    (asserts! (is-eq tx-sender sender) err-unauthorized)
    (asserts! (<= amount sender-balance) err-insufficient-balance)
    (asserts! (not (is-eq sender recipient)) err-invalid-data)
    
    (map-set token-balances sender (- sender-balance amount))
    (map-set token-balances recipient (+ (get-balance-uint recipient) amount))
    (print {action: "transfer", sender: sender, recipient: recipient, amount: amount, memo: memo})
    (ok true)
  )
)

;; Get token name
(define-read-only (get-name)
  (ok token-name)
)

;; Get token symbol
(define-read-only (get-symbol)
  (ok token-symbol)
)

;; Get token decimals
(define-read-only (get-decimals)
  (ok token-decimals)
)

;; Get token balance
(define-read-only (get-balance (account principal))
  (ok (get-balance-uint account))
)

;; Get total supply
(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

;; Get token URI
(define-read-only (get-token-uri (token-id (optional uint)))
  (ok (some token-uri))
)

;; Public Functions

;; Submit conservation activity
(define-public (submit-conservation-activity
    (activity-type (string-ascii 32))
    (description (string-ascii 256))
    (location-lat int)
    (location-lon int)
  )
  (let ((activity-id (var-get next-activity-id)))
    (asserts! (> (len description) u0) err-invalid-data)
    
    (map-set conservation-activities
      { activity-id: activity-id }
      {
        participant: tx-sender,
        activity-type: activity-type,
        description: description,
        location-lat: location-lat,
        location-lon: location-lon,
        submission-date: stacks-block-height,
        verification-status: "pending",
        verifier: none,
        reward-amount: u0,
        is-rewarded: false
      }
    )
    
    (var-set next-activity-id (+ activity-id u1))
    (ok activity-id)
  )
)

;; Submit gardening initiative
(define-public (submit-gardening-initiative
    (initiative-id uint)
    (plant-species (string-ascii 64))
    (quantity-planted uint)
    (area-size uint)
    (native-plants-ratio uint)
    (pollinator-friendly-score uint)
    (maintenance-commitment uint)
  )
  (begin
    (asserts! (and (> quantity-planted u0) (> area-size u0)) err-invalid-data)
    (asserts! (and (<= native-plants-ratio u100) (<= pollinator-friendly-score u100)) err-invalid-data)
    
    (map-set gardening-initiatives
      { initiative-id: initiative-id }
      {
        participant: tx-sender,
        plant-species: plant-species,
        quantity-planted: quantity-planted,
        area-size: area-size,
        planting-date: stacks-block-height,
        native-plants-ratio: native-plants-ratio,
        pollinator-friendly-score: pollinator-friendly-score,
        maintenance-commitment: maintenance-commitment
      }
    )
    
    ;; Auto-submit as conservation activity
    (submit-conservation-activity "gardening" plant-species 0 0)
  )
)

;; Submit pesticide reduction record
(define-public (submit-pesticide-reduction
    (record-id uint)
    (previous-usage uint)
    (current-usage uint)
    (area-affected uint)
    (verification-method (string-ascii 64))
    (baseline-date uint)
  )
  (let ((reduction-percentage (calculate-reduction-percentage previous-usage current-usage)))
    (asserts! (and (> previous-usage current-usage) (> area-affected u0)) err-invalid-data)
    
    (map-set pesticide-reduction-records
      { record-id: record-id }
      {
        participant: tx-sender,
        previous-usage: previous-usage,
        current-usage: current-usage,
        reduction-percentage: reduction-percentage,
        area-affected: area-affected,
        verification-method: verification-method,
        baseline-date: baseline-date,
        measurement-date: stacks-block-height
      }
    )
    
    ;; Auto-submit as conservation activity
    (submit-conservation-activity "pesticide-reduction" verification-method 0 0)
  )
)

;; Submit citizen science contribution
(define-public (submit-citizen-science-contribution
    (contribution-id uint)
    (contribution-type (string-ascii 64))
    (observations-count uint)
    (research-value uint)
  )
  (begin
    (asserts! (and (> observations-count u0) (<= research-value u100)) err-invalid-data)
    
    (map-set citizen-science-contributions
      { contribution-id: contribution-id }
      {
        participant: tx-sender,
        contribution-type: contribution-type,
        data-quality-score: u0,
        observations-count: observations-count,
        submission-date: stacks-block-height,
        research-value: research-value,
        peer-review-score: u0
      }
    )
    
    ;; Auto-submit as conservation activity
    (submit-conservation-activity "citizen-science" contribution-type 0 0)
  )
)

;; Verify and approve activity for rewards
(define-public (verify-activity
    (activity-id uint)
    (verification-status (string-ascii 32))
    (reward-amount uint)
  )
  (let ((activity-data (unwrap! (map-get? conservation-activities { activity-id: activity-id }) err-not-found)))
    (asserts! (is-authorized-verifier tx-sender) err-unauthorized)
    (asserts! (is-eq (get verification-status activity-data) "pending") err-invalid-data)
    
    (map-set conservation-activities
      { activity-id: activity-id }
      (merge activity-data {
        verification-status: verification-status,
        verifier: (some tx-sender),
        reward-amount: reward-amount
      })
    )
    
    ;; If approved, mint and distribute rewards
    (if (is-eq verification-status "approved")
      (distribute-reward (get participant activity-data) reward-amount)
      (ok true)
    )
  )
)

;; Distribute reward tokens
(define-public (distribute-reward (participant principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (<= (+ (var-get total-supply) amount) max-supply) err-invalid-data)
    
    (var-set total-supply (+ (var-get total-supply) amount))
    (map-set token-balances participant (+ (get-balance-uint participant) amount))
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) amount))
    
    (update-participant-profile participant amount)
    (ok true)
  )
)

;; Authorize verifier
(define-public (authorize-verifier
    (verifier principal)
    (verification-authority (string-ascii 128))
    (specialization (string-ascii 64))
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    
    (map-set authorized-verifiers
      { verifier: verifier }
      {
        is-authorized: true,
        verification-authority: verification-authority,
        specialization: specialization,
        verifications-completed: u0,
        accuracy-rating: u100
      }
    )
    (ok true)
  )
)

;; Set reward multipliers
(define-public (set-reward-multipliers
    (activity-type (string-ascii 32))
    (base-multiplier uint)
    (seasonal-bonus uint)
    (quality-bonus uint)
    (community-bonus uint)
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    
    (map-set reward-multipliers
      { activity-type: activity-type }
      {
        base-multiplier: base-multiplier,
        seasonal-bonus: seasonal-bonus,
        quality-bonus: quality-bonus,
        community-bonus: community-bonus
      }
    )
    (ok true)
  )
)

;; Read-only functions

;; Get conservation activity
(define-read-only (get-conservation-activity (activity-id uint))
  (map-get? conservation-activities { activity-id: activity-id })
)

;; Get gardening initiative
(define-read-only (get-gardening-initiative (initiative-id uint))
  (map-get? gardening-initiatives { initiative-id: initiative-id })
)

;; Get pesticide reduction record
(define-read-only (get-pesticide-reduction-record (record-id uint))
  (map-get? pesticide-reduction-records { record-id: record-id })
)

;; Get citizen science contribution
(define-read-only (get-citizen-science-contribution (contribution-id uint))
  (map-get? citizen-science-contributions { contribution-id: contribution-id })
)

;; Get participant profile
(define-read-only (get-participant-profile (participant principal))
  (map-get? participant-profiles { participant: participant })
)

;; Get balance as uint
(define-read-only (get-balance-uint (account principal))
  (default-to u0 (map-get? token-balances account))
)

;; Get total rewards distributed
(define-read-only (get-total-rewards-distributed)
  (var-get total-rewards-distributed)
)

;; Get active participants count
(define-read-only (get-active-participants)
  (var-get active-participants)
)

;; Check if verifier is authorized
(define-read-only (is-authorized-verifier (verifier principal))
  (default-to false
    (get is-authorized
      (map-get? authorized-verifiers { verifier: verifier })
    )
  )
)

;; Calculate reward amount based on activity type
(define-read-only (calculate-reward-amount (activity-type (string-ascii 32)) (quality-score uint))
  (let 
    (
      (base-reward (if (is-eq activity-type "gardening") 
        gardening-reward
        (if (is-eq activity-type "pesticide-reduction")
          pesticide-reduction-reward
          (if (is-eq activity-type "citizen-science")
            citizen-science-reward
            (if (is-eq activity-type "habitat-creation")
              habitat-creation-reward
              research-contribution-reward
            )
          )
        )
      ))
      (quality-bonus (/ (* base-reward quality-score) u100))
    )
    (+ base-reward quality-bonus)
  )
)

;; Private functions

;; Update participant profile with rewards
(define-private (update-participant-profile (participant principal) (reward-amount uint))
  (let 
    (
      (current-profile (default-to
        {
          total-rewards-earned: u0,
          activities-completed: u0,
          conservation-score: u0,
          registration-date: stacks-block-height,
          reputation-level: "bronze",
          specializations: ""
        }
        (map-get? participant-profiles { participant: participant })
      ))
    )
    (map-set participant-profiles
      { participant: participant }
      (merge current-profile {
        total-rewards-earned: (+ (get total-rewards-earned current-profile) reward-amount),
        activities-completed: (+ (get activities-completed current-profile) u1),
        conservation-score: (+ (get conservation-score current-profile) u10)
      })
    )
  )
)

;; Calculate percentage reduction
(define-private (calculate-reduction-percentage (previous uint) (current uint))
  (if (> previous u0)
    (/ (* (- previous current) u100) previous)
    u0
  )
)

