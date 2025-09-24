;; PollinatorChain-Network: Flight Tracking Contract
;; RFID tags and observation networks for mapping pollinator movement patterns

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u401))
(define-constant err-not-found (err u404))
(define-constant err-invalid-data (err u400))
(define-constant err-already-exists (err u409))
(define-constant max-rfid-id u999999999)
(define-constant max-coordinates u18000000) ;; 180.000000 degrees * 100000

;; Data Variables
(define-data-var next-tracking-id uint u1)
(define-data-var total-pollinators uint u0)
(define-data-var active-researchers uint u0)

;; Data Maps
(define-map rfid-tags 
  { rfid-id: uint }
  { 
    pollinator-type: (string-ascii 32),
    species: (string-ascii 64),
    deployment-date: uint,
    battery-level: uint,
    is-active: bool,
    researcher: principal
  }
)

(define-map tracking-records
  { tracking-id: uint }
  {
    rfid-id: uint,
    timestamp: uint,
    latitude: int,
    longitude: int,
    altitude: uint,
    speed: uint,
    direction: uint,
    temperature: uint,
    humidity: uint,
    activity-type: (string-ascii 32)
  }
)

(define-map pollinator-profiles
  { rfid-id: uint }
  {
    total-distance: uint,
    flight-hours: uint,
    flower-visits: uint,
    nest-returns: uint,
    health-status: (string-ascii 32),
    last-seen: uint
  }
)

(define-map observation-stations
  { station-id: uint }
  {
    name: (string-ascii 64),
    latitude: int,
    longitude: int,
    operator: principal,
    installation-date: uint,
    detection-range: uint,
    is-operational: bool
  }
)

(define-map researcher-permissions
  { researcher: principal }
  {
    is-authorized: bool,
    specialization: (string-ascii 64),
    institution: (string-ascii 128),
    registration-date: uint
  }
)

;; Migration tracking
(define-map migration-patterns
  { pattern-id: uint }
  {
    species: (string-ascii 64),
    start-season: uint,
    end-season: uint,
    origin-lat: int,
    origin-lon: int,
    destination-lat: int,
    destination-lon: int,
    distance: uint,
    duration: uint
  }
)

;; Public Functions

;; Register RFID tag for new pollinator
(define-public (register-rfid-tag (rfid-id uint) (pollinator-type (string-ascii 32)) (species (string-ascii 64)))
  (let ((researcher tx-sender))
    (asserts! (is-authorized-researcher researcher) err-unauthorized)
    (asserts! (<= rfid-id max-rfid-id) err-invalid-data)
    (asserts! (is-none (map-get? rfid-tags { rfid-id: rfid-id })) err-already-exists)
    (map-set rfid-tags
      { rfid-id: rfid-id }
      {
        pollinator-type: pollinator-type,
        species: species,
        deployment-date: stacks-block-height,
        battery-level: u100,
        is-active: true,
        researcher: researcher
      }
    )
    (var-set total-pollinators (+ (var-get total-pollinators) u1))
    (ok rfid-id)
  )
)

;; Record tracking data
(define-public (record-tracking-data 
    (rfid-id uint) 
    (latitude int) 
    (longitude int) 
    (altitude uint)
    (speed uint)
    (direction uint)
    (temperature uint)
    (humidity uint)
    (activity-type (string-ascii 32))
  )
  (let 
    (
      (tracking-id (var-get next-tracking-id))
      (researcher tx-sender)
    )
    (asserts! (is-authorized-researcher researcher) err-unauthorized)
    (asserts! (is-some (map-get? rfid-tags { rfid-id: rfid-id })) err-not-found)
    (asserts! (and (<= (to-uint (if (< latitude 0) (* latitude -1) latitude)) max-coordinates) (<= (to-uint (if (< longitude 0) (* longitude -1) longitude)) max-coordinates)) err-invalid-data)
    
    (map-set tracking-records
      { tracking-id: tracking-id }
      {
        rfid-id: rfid-id,
        timestamp: stacks-block-height,
        latitude: latitude,
        longitude: longitude,
        altitude: altitude,
        speed: speed,
        direction: direction,
        temperature: temperature,
        humidity: humidity,
        activity-type: activity-type
      }
    )
    (var-set next-tracking-id (+ tracking-id u1))
    (update-pollinator-profile rfid-id speed)
    (ok tracking-id)
  )
)

;; Register researcher
(define-public (register-researcher (researcher principal) (specialization (string-ascii 64)) (institution (string-ascii 128)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (map-set researcher-permissions
      { researcher: researcher }
      {
        is-authorized: true,
        specialization: specialization,
        institution: institution,
        registration-date: stacks-block-height
      }
    )
    (var-set active-researchers (+ (var-get active-researchers) u1))
    (ok true)
  )
)

;; Setup observation station
(define-public (setup-observation-station 
    (station-id uint)
    (name (string-ascii 64))
    (latitude int)
    (longitude int)
    (detection-range uint)
  )
  (begin
    (asserts! (is-authorized-researcher tx-sender) err-unauthorized)
    (asserts! (and (<= (to-uint (if (< latitude 0) (* latitude -1) latitude)) max-coordinates) (<= (to-uint (if (< longitude 0) (* longitude -1) longitude)) max-coordinates)) err-invalid-data)
    (map-set observation-stations
      { station-id: station-id }
      {
        name: name,
        latitude: latitude,
        longitude: longitude,
        operator: tx-sender,
        installation-date: stacks-block-height,
        detection-range: detection-range,
        is-operational: true
      }
    )
    (ok station-id)
  )
)

;; Record migration pattern
(define-public (record-migration-pattern
    (pattern-id uint)
    (species (string-ascii 64))
    (start-season uint)
    (end-season uint)
    (origin-lat int)
    (origin-lon int)
    (destination-lat int)
    (destination-lon int)
    (distance uint)
  )
  (begin
    (asserts! (is-authorized-researcher tx-sender) err-unauthorized)
    (asserts! (and 
      (<= (to-uint (if (< origin-lat 0) (* origin-lat -1) origin-lat)) max-coordinates) 
      (<= (to-uint (if (< origin-lon 0) (* origin-lon -1) origin-lon)) max-coordinates)
      (<= (to-uint (if (< destination-lat 0) (* destination-lat -1) destination-lat)) max-coordinates) 
      (<= (to-uint (if (< destination-lon 0) (* destination-lon -1) destination-lon)) max-coordinates)
    ) err-invalid-data)
    (map-set migration-patterns
      { pattern-id: pattern-id }
      {
        species: species,
        start-season: start-season,
        end-season: end-season,
        origin-lat: origin-lat,
        origin-lon: origin-lon,
        destination-lat: destination-lat,
        destination-lon: destination-lon,
        distance: distance,
        duration: (- end-season start-season)
      }
    )
    (ok pattern-id)
  )
)

;; Update battery level
(define-public (update-battery-level (rfid-id uint) (new-level uint))
  (let ((tag-data (unwrap! (map-get? rfid-tags { rfid-id: rfid-id }) err-not-found)))
    (asserts! (is-eq (get researcher tag-data) tx-sender) err-unauthorized)
    (asserts! (<= new-level u100) err-invalid-data)
    (map-set rfid-tags
      { rfid-id: rfid-id }
      (merge tag-data { battery-level: new-level })
    )
    (ok true)
  )
)

;; Read-only functions

;; Get RFID tag data
(define-read-only (get-rfid-tag (rfid-id uint))
  (map-get? rfid-tags { rfid-id: rfid-id })
)

;; Get tracking record
(define-read-only (get-tracking-record (tracking-id uint))
  (map-get? tracking-records { tracking-id: tracking-id })
)

;; Get pollinator profile
(define-read-only (get-pollinator-profile (rfid-id uint))
  (map-get? pollinator-profiles { rfid-id: rfid-id })
)

;; Get observation station
(define-read-only (get-observation-station (station-id uint))
  (map-get? observation-stations { station-id: station-id })
)

;; Get migration pattern
(define-read-only (get-migration-pattern (pattern-id uint))
  (map-get? migration-patterns { pattern-id: pattern-id })
)

;; Get total pollinators count
(define-read-only (get-total-pollinators)
  (var-get total-pollinators)
)

;; Get active researchers count
(define-read-only (get-active-researchers)
  (var-get active-researchers)
)

;; Check if researcher is authorized
(define-read-only (is-authorized-researcher (researcher principal))
  (default-to false 
    (get is-authorized 
      (map-get? researcher-permissions { researcher: researcher })
    )
  )
)

;; Private functions

;; Update pollinator profile with flight data
(define-private (update-pollinator-profile (rfid-id uint) (speed uint))
  (let 
    (
      (current-profile (default-to 
        {
          total-distance: u0,
          flight-hours: u0,
          flower-visits: u0,
          nest-returns: u0,
          health-status: "active",
          last-seen: u0
        }
        (map-get? pollinator-profiles { rfid-id: rfid-id })
      ))
    )
    (map-set pollinator-profiles
      { rfid-id: rfid-id }
      (merge current-profile {
        total-distance: (+ (get total-distance current-profile) speed),
        last-seen: stacks-block-height
      })
    )
  )
)

