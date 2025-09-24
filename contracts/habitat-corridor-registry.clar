;; PollinatorChain-Network: Habitat Corridor Registry Contract
;; Native flowering plant corridor mapping and certification

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u401))
(define-constant err-not-found (err u404))
(define-constant err-invalid-data (err u400))
(define-constant err-already-exists (err u409))
(define-constant err-insufficient-score (err u422))
(define-constant min-certification-score u75)
(define-constant max-coordinates u18000000) ;; 180.000000 degrees * 100000

;; Data Variables
(define-data-var next-corridor-id uint u1)
(define-data-var next-certification-id uint u1)
(define-data-var total-corridors uint u0)
(define-data-var certified-corridors uint u0)
(define-data-var total-protected-area uint u0)

;; Data Maps
(define-map habitat-corridors
  { corridor-id: uint }
  {
    name: (string-ascii 128),
    owner: principal,
    start-lat: int,
    start-lon: int,
    end-lat: int,
    end-lon: int,
    total-length: uint,
    total-area: uint,
    establishment-date: uint,
    status: (string-ascii 32)
  }
)

(define-map native-plants
  { corridor-id: uint, plant-id: uint }
  {
    species-name: (string-ascii 64),
    common-name: (string-ascii 64),
    bloom-season: (string-ascii 32),
    nectar-rating: uint,
    pollen-rating: uint,
    quantity: uint,
    planting-date: uint,
    maturity-status: (string-ascii 32)
  }
)

(define-map biodiversity-metrics
  { corridor-id: uint }
  {
    plant-species-count: uint,
    native-species-ratio: uint,
    bloom-coverage-months: uint,
    pollinator-attractiveness: uint,
    habitat-quality-score: uint,
    last-assessment: uint,
    assessor: principal
  }
)

(define-map certification-records
  { certification-id: uint }
  {
    corridor-id: uint,
    certification-level: (string-ascii 32),
    issue-date: uint,
    expiry-date: uint,
    certifier: principal,
    certification-score: uint,
    requirements-met: (string-ascii 256),
    is-active: bool
  }
)

(define-map maintenance-logs
  { corridor-id: uint, log-id: uint }
  {
    maintenance-date: uint,
    maintenance-type: (string-ascii 64),
    description: (string-ascii 256),
    maintainer: principal,
    cost: uint,
    effectiveness: uint
  }
)

(define-map corridor-connections
  { connection-id: uint }
  {
    corridor-a: uint,
    corridor-b: uint,
    connection-type: (string-ascii 32),
    distance: uint,
    connectivity-score: uint,
    verified: bool
  }
)

(define-map authorized-certifiers
  { certifier: principal }
  {
    is-authorized: bool,
    certification-authority: (string-ascii 128),
    specialization: (string-ascii 64),
    license-number: (string-ascii 64),
    authorization-date: uint
  }
)

(define-map corridor-owners
  { owner: principal }
  {
    corridors-owned: uint,
    total-certified-area: uint,
    average-quality-score: uint,
    registration-date: uint,
    contact-info: (string-ascii 256)
  }
)

;; Public Functions

;; Register new habitat corridor
(define-public (register-habitat-corridor
    (name (string-ascii 128))
    (start-lat int)
    (start-lon int)
    (end-lat int)
    (end-lon int)
    (total-length uint)
    (total-area uint)
  )
  (let ((corridor-id (var-get next-corridor-id)))
    (asserts! (and 
      (<= (to-uint (if (< start-lat 0) (* start-lat -1) start-lat)) max-coordinates)
      (<= (to-uint (if (< start-lon 0) (* start-lon -1) start-lon)) max-coordinates)
      (<= (to-uint (if (< end-lat 0) (* end-lat -1) end-lat)) max-coordinates)
      (<= (to-uint (if (< end-lon 0) (* end-lon -1) end-lon)) max-coordinates)
    ) err-invalid-data)
    (asserts! (and (> total-length u0) (> total-area u0)) err-invalid-data)
    
    (map-set habitat-corridors
      { corridor-id: corridor-id }
      {
        name: name,
        owner: tx-sender,
        start-lat: start-lat,
        start-lon: start-lon,
        end-lat: end-lat,
        end-lon: end-lon,
        total-length: total-length,
        total-area: total-area,
        establishment-date: stacks-block-height,
        status: "registered"
      }
    )
    
    (var-set next-corridor-id (+ corridor-id u1))
    (var-set total-corridors (+ (var-get total-corridors) u1))
    (var-set total-protected-area (+ (var-get total-protected-area) total-area))
    (update-owner-stats tx-sender total-area)
    (ok corridor-id)
  )
)

;; Add native plant species to corridor
(define-public (add-native-plant
    (corridor-id uint)
    (plant-id uint)
    (species-name (string-ascii 64))
    (common-name (string-ascii 64))
    (bloom-season (string-ascii 32))
    (nectar-rating uint)
    (pollen-rating uint)
    (quantity uint)
  )
  (let ((corridor-data (unwrap! (map-get? habitat-corridors { corridor-id: corridor-id }) err-not-found)))
    (asserts! (is-eq (get owner corridor-data) tx-sender) err-unauthorized)
    (asserts! (and (<= nectar-rating u10) (<= pollen-rating u10)) err-invalid-data)
    (asserts! (> quantity u0) err-invalid-data)
    
    (map-set native-plants
      { corridor-id: corridor-id, plant-id: plant-id }
      {
        species-name: species-name,
        common-name: common-name,
        bloom-season: bloom-season,
        nectar-rating: nectar-rating,
        pollen-rating: pollen-rating,
        quantity: quantity,
        planting-date: stacks-block-height,
        maturity-status: "newly-planted"
      }
    )
    (update-biodiversity-metrics corridor-id)
    (ok true)
  )
)

;; Assess biodiversity metrics
(define-public (assess-biodiversity
    (corridor-id uint)
    (plant-species-count uint)
    (native-species-ratio uint)
    (bloom-coverage-months uint)
    (pollinator-attractiveness uint)
    (habitat-quality-score uint)
  )
  (begin
    (asserts! (is-some (map-get? habitat-corridors { corridor-id: corridor-id })) err-not-found)
    (asserts! (and 
      (<= native-species-ratio u100)
      (<= bloom-coverage-months u12)
      (<= pollinator-attractiveness u100)
      (<= habitat-quality-score u100)
    ) err-invalid-data)
    
    (map-set biodiversity-metrics
      { corridor-id: corridor-id }
      {
        plant-species-count: plant-species-count,
        native-species-ratio: native-species-ratio,
        bloom-coverage-months: bloom-coverage-months,
        pollinator-attractiveness: pollinator-attractiveness,
        habitat-quality-score: habitat-quality-score,
        last-assessment: stacks-block-height,
        assessor: tx-sender
      }
    )
    (ok true)
  )
)

;; Issue corridor certification
(define-public (issue-certification
    (corridor-id uint)
    (certification-level (string-ascii 32))
    (certification-score uint)
    (requirements-met (string-ascii 256))
    (validity-period uint)
  )
  (let 
    (
      (certification-id (var-get next-certification-id))
      (corridor-data (unwrap! (map-get? habitat-corridors { corridor-id: corridor-id }) err-not-found))
    )
    (asserts! (is-authorized-certifier tx-sender) err-unauthorized)
    (asserts! (>= certification-score min-certification-score) err-insufficient-score)
    (asserts! (<= certification-score u100) err-invalid-data)
    
    (map-set certification-records
      { certification-id: certification-id }
      {
        corridor-id: corridor-id,
        certification-level: certification-level,
        issue-date: stacks-block-height,
        expiry-date: (+ stacks-block-height validity-period),
        certifier: tx-sender,
        certification-score: certification-score,
        requirements-met: requirements-met,
        is-active: true
      }
    )
    
    ;; Update corridor status
    (map-set habitat-corridors
      { corridor-id: corridor-id }
      (merge corridor-data { status: "certified" })
    )
    
    (var-set next-certification-id (+ certification-id u1))
    (var-set certified-corridors (+ (var-get certified-corridors) u1))
    (ok certification-id)
  )
)

;; Log maintenance activity
(define-public (log-maintenance
    (corridor-id uint)
    (log-id uint)
    (maintenance-type (string-ascii 64))
    (description (string-ascii 256))
    (cost uint)
    (effectiveness uint)
  )
  (let ((corridor-data (unwrap! (map-get? habitat-corridors { corridor-id: corridor-id }) err-not-found)))
    (asserts! (is-eq (get owner corridor-data) tx-sender) err-unauthorized)
    (asserts! (<= effectiveness u100) err-invalid-data)
    
    (map-set maintenance-logs
      { corridor-id: corridor-id, log-id: log-id }
      {
        maintenance-date: stacks-block-height,
        maintenance-type: maintenance-type,
        description: description,
        maintainer: tx-sender,
        cost: cost,
        effectiveness: effectiveness
      }
    )
    (ok true)
  )
)

;; Create corridor connection
(define-public (create-corridor-connection
    (connection-id uint)
    (corridor-a uint)
    (corridor-b uint)
    (connection-type (string-ascii 32))
    (distance uint)
    (connectivity-score uint)
  )
  (begin
    (asserts! (is-some (map-get? habitat-corridors { corridor-id: corridor-a })) err-not-found)
    (asserts! (is-some (map-get? habitat-corridors { corridor-id: corridor-b })) err-not-found)
    (asserts! (not (is-eq corridor-a corridor-b)) err-invalid-data)
    (asserts! (<= connectivity-score u100) err-invalid-data)
    
    (map-set corridor-connections
      { connection-id: connection-id }
      {
        corridor-a: corridor-a,
        corridor-b: corridor-b,
        connection-type: connection-type,
        distance: distance,
        connectivity-score: connectivity-score,
        verified: false
      }
    )
    (ok connection-id)
  )
)

;; Authorize certifier
(define-public (authorize-certifier
    (certifier principal)
    (certification-authority (string-ascii 128))
    (specialization (string-ascii 64))
    (license-number (string-ascii 64))
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    
    (map-set authorized-certifiers
      { certifier: certifier }
      {
        is-authorized: true,
        certification-authority: certification-authority,
        specialization: specialization,
        license-number: license-number,
        authorization-date: stacks-block-height
      }
    )
    (ok true)
  )
)

;; Read-only functions

;; Get habitat corridor data
(define-read-only (get-habitat-corridor (corridor-id uint))
  (map-get? habitat-corridors { corridor-id: corridor-id })
)

;; Get native plant data
(define-read-only (get-native-plant (corridor-id uint) (plant-id uint))
  (map-get? native-plants { corridor-id: corridor-id, plant-id: plant-id })
)

;; Get biodiversity metrics
(define-read-only (get-biodiversity-metrics (corridor-id uint))
  (map-get? biodiversity-metrics { corridor-id: corridor-id })
)

;; Get certification record
(define-read-only (get-certification-record (certification-id uint))
  (map-get? certification-records { certification-id: certification-id })
)

;; Get maintenance log
(define-read-only (get-maintenance-log (corridor-id uint) (log-id uint))
  (map-get? maintenance-logs { corridor-id: corridor-id, log-id: log-id })
)

;; Get corridor connection
(define-read-only (get-corridor-connection (connection-id uint))
  (map-get? corridor-connections { connection-id: connection-id })
)

;; Get total corridors
(define-read-only (get-total-corridors)
  (var-get total-corridors)
)

;; Get certified corridors
(define-read-only (get-certified-corridors)
  (var-get certified-corridors)
)

;; Get total protected area
(define-read-only (get-total-protected-area)
  (var-get total-protected-area)
)

;; Check if certifier is authorized
(define-read-only (is-authorized-certifier (certifier principal))
  (default-to false
    (get is-authorized
      (map-get? authorized-certifiers { certifier: certifier })
    )
  )
)

;; Calculate certification eligibility
(define-read-only (check-certification-eligibility (corridor-id uint))
  (match (map-get? biodiversity-metrics { corridor-id: corridor-id })
    metrics (let 
      (
        (quality-score (get habitat-quality-score metrics))
        (native-ratio (get native-species-ratio metrics))
        (bloom-coverage (get bloom-coverage-months metrics))
      )
      {
        eligible: (and 
          (>= quality-score min-certification-score)
          (>= native-ratio u60)
          (>= bloom-coverage u6)
        ),
        score: (/ (+ quality-score native-ratio bloom-coverage) u3)
      }
    )
    { eligible: false, score: u0 }
  )
)

;; Private functions

;; Update owner statistics
(define-private (update-owner-stats (owner principal) (area uint))
  (let 
    (
      (current-stats (default-to
        {
          corridors-owned: u0,
          total-certified-area: u0,
          average-quality-score: u0,
          registration-date: stacks-block-height,
          contact-info: ""
        }
        (map-get? corridor-owners { owner: owner })
      ))
    )
    (map-set corridor-owners
      { owner: owner }
      (merge current-stats {
        corridors-owned: (+ (get corridors-owned current-stats) u1),
        total-certified-area: (+ (get total-certified-area current-stats) area)
      })
    )
  )
)

;; Update biodiversity metrics automatically
(define-private (update-biodiversity-metrics (corridor-id uint))
  (let 
    (
      (current-metrics (default-to
        {
          plant-species-count: u1,
          native-species-ratio: u100,
          bloom-coverage-months: u3,
          pollinator-attractiveness: u70,
          habitat-quality-score: u70,
          last-assessment: stacks-block-height,
          assessor: tx-sender
        }
        (map-get? biodiversity-metrics { corridor-id: corridor-id })
      ))
    )
    (map-set biodiversity-metrics
      { corridor-id: corridor-id }
      (merge current-metrics {
        plant-species-count: (+ (get plant-species-count current-metrics) u1),
        last-assessment: stacks-block-height,
        assessor: tx-sender
      })
    )
  )
)

