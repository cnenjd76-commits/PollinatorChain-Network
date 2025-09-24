;; PollinatorChain-Network: Pesticide Exposure Monitoring Contract
;; Chemical residue testing and health impact assessment

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u401))
(define-constant err-not-found (err u404))
(define-constant err-invalid-data (err u400))
(define-constant err-already-exists (err u409))
(define-constant max-concentration u10000000) ;; 10,000.0000 ppm * 10000
(define-constant danger-threshold u1000000) ;; 100.0000 ppm * 10000
(define-constant warning-threshold u500000)  ;; 50.0000 ppm * 10000

;; Data Variables
(define-data-var next-sample-id uint u1)
(define-data-var next-incident-id uint u1)
(define-data-var total-samples uint u0)
(define-data-var dangerous-exposures uint u0)
(define-data-var active-labs uint u0)

;; Data Maps
(define-map pollen-samples
  { sample-id: uint }
  {
    location-lat: int,
    location-lon: int,
    collection-date: uint,
    collector: principal,
    plant-species: (string-ascii 64),
    sample-weight: uint,
    lab-id: uint,
    status: (string-ascii 32)
  }
)

(define-map chemical-analysis
  { sample-id: uint }
  {
    pesticide-name: (string-ascii 64),
    concentration: uint,
    detection-method: (string-ascii 32),
    analysis-date: uint,
    analyst: principal,
    certified: bool
  }
)

(define-map health-assessments
  { assessment-id: uint }
  {
    sample-id: uint,
    exposure-level: uint,
    risk-category: (string-ascii 32),
    health-impact: (string-ascii 128),
    mortality-risk: uint,
    reproduction-impact: uint,
    behavioral-effects: (string-ascii 128)
  }
)

(define-map exposure-incidents
  { incident-id: uint }
  {
    location-lat: int,
    location-lon: int,
    incident-date: uint,
    pesticide-type: (string-ascii 64),
    concentration: uint,
    affected-area: uint,
    pollinator-casualties: uint,
    reporter: principal,
    severity: (string-ascii 32)
  }
)

(define-map laboratory-certifications
  { lab-id: uint }
  {
    name: (string-ascii 128),
    certification-level: (string-ascii 32),
    accreditation-date: uint,
    contact-info: (string-ascii 256),
    specializations: (string-ascii 128),
    is-active: bool
  }
)

(define-map regional-alerts
  { region-id: uint }
  {
    region-name: (string-ascii 64),
    alert-level: (string-ascii 32),
    pesticide-detected: (string-ascii 64),
    concentration: uint,
    alert-date: uint,
    expiry-date: uint,
    affected-species: (string-ascii 128)
  }
)

(define-map authorized-collectors
  { collector: principal }
  {
    is-authorized: bool,
    certification: (string-ascii 64),
    institution: (string-ascii 128),
    training-date: uint,
    samples-collected: uint
  }
)

;; Public Functions

;; Submit pollen sample for analysis
(define-public (submit-pollen-sample
    (location-lat int)
    (location-lon int)
    (plant-species (string-ascii 64))
    (sample-weight uint)
    (lab-id uint)
  )
  (let ((sample-id (var-get next-sample-id)))
    (asserts! (is-authorized-collector tx-sender) err-unauthorized)
    (asserts! (is-some (map-get? laboratory-certifications { lab-id: lab-id })) err-not-found)
    (asserts! (> sample-weight u0) err-invalid-data)
    
    (map-set pollen-samples
      { sample-id: sample-id }
      {
        location-lat: location-lat,
        location-lon: location-lon,
        collection-date: stacks-block-height,
        collector: tx-sender,
        plant-species: plant-species,
        sample-weight: sample-weight,
        lab-id: lab-id,
        status: "submitted"
      }
    )
    (var-set next-sample-id (+ sample-id u1))
    (var-set total-samples (+ (var-get total-samples) u1))
    (update-collector-stats tx-sender)
    (ok sample-id)
  )
)

;; Record chemical analysis results
(define-public (record-chemical-analysis
    (sample-id uint)
    (pesticide-name (string-ascii 64))
    (concentration uint)
    (detection-method (string-ascii 32))
  )
  (let 
    (
      (sample-data (unwrap! (map-get? pollen-samples { sample-id: sample-id }) err-not-found))
      (lab-data (unwrap! (map-get? laboratory-certifications { lab-id: (get lab-id sample-data) }) err-not-found))
    )
    (asserts! (get is-active lab-data) err-unauthorized)
    (asserts! (<= concentration max-concentration) err-invalid-data)
    
    (map-set chemical-analysis
      { sample-id: sample-id }
      {
        pesticide-name: pesticide-name,
        concentration: concentration,
        detection-method: detection-method,
        analysis-date: stacks-block-height,
        analyst: tx-sender,
        certified: true
      }
    )
    
    ;; Update sample status
    (map-set pollen-samples
      { sample-id: sample-id }
      (merge sample-data { status: "analyzed" })
    )
    
    ;; Check for dangerous levels
    (if (>= concentration danger-threshold)
      (begin
        (var-set dangerous-exposures (+ (var-get dangerous-exposures) u1))
        (create-regional-alert sample-data pesticide-name concentration)
      )
      true
    )
    
    (ok true)
  )
)

;; Conduct health assessment
(define-public (conduct-health-assessment
    (sample-id uint)
    (exposure-level uint)
    (risk-category (string-ascii 32))
    (health-impact (string-ascii 128))
    (mortality-risk uint)
    (reproduction-impact uint)
    (behavioral-effects (string-ascii 128))
  )
  (let ((assessment-id (var-get next-incident-id)))
    (asserts! (is-some (map-get? chemical-analysis { sample-id: sample-id })) err-not-found)
    (asserts! (<= mortality-risk u100) err-invalid-data)
    (asserts! (<= reproduction-impact u100) err-invalid-data)
    
    (map-set health-assessments
      { assessment-id: assessment-id }
      {
        sample-id: sample-id,
        exposure-level: exposure-level,
        risk-category: risk-category,
        health-impact: health-impact,
        mortality-risk: mortality-risk,
        reproduction-impact: reproduction-impact,
        behavioral-effects: behavioral-effects
      }
    )
    (var-set next-incident-id (+ assessment-id u1))
    (ok assessment-id)
  )
)

;; Report exposure incident
(define-public (report-exposure-incident
    (location-lat int)
    (location-lon int)
    (pesticide-type (string-ascii 64))
    (concentration uint)
    (affected-area uint)
    (pollinator-casualties uint)
    (severity (string-ascii 32))
  )
  (let ((incident-id (var-get next-incident-id)))
    (asserts! (is-authorized-collector tx-sender) err-unauthorized)
    (asserts! (<= concentration max-concentration) err-invalid-data)
    
    (map-set exposure-incidents
      { incident-id: incident-id }
      {
        location-lat: location-lat,
        location-lon: location-lon,
        incident-date: stacks-block-height,
        pesticide-type: pesticide-type,
        concentration: concentration,
        affected-area: affected-area,
        pollinator-casualties: pollinator-casualties,
        reporter: tx-sender,
        severity: severity
      }
    )
    (var-set next-incident-id (+ incident-id u1))
    (ok incident-id)
  )
)

;; Register laboratory
(define-public (register-laboratory
    (lab-id uint)
    (name (string-ascii 128))
    (certification-level (string-ascii 32))
    (contact-info (string-ascii 256))
    (specializations (string-ascii 128))
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (asserts! (is-none (map-get? laboratory-certifications { lab-id: lab-id })) err-already-exists)
    
    (map-set laboratory-certifications
      { lab-id: lab-id }
      {
        name: name,
        certification-level: certification-level,
        accreditation-date: stacks-block-height,
        contact-info: contact-info,
        specializations: specializations,
        is-active: true
      }
    )
    (var-set active-labs (+ (var-get active-labs) u1))
    (ok lab-id)
  )
)

;; Authorize sample collector
(define-public (authorize-collector
    (collector principal)
    (certification (string-ascii 64))
    (institution (string-ascii 128))
  )
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    
    (map-set authorized-collectors
      { collector: collector }
      {
        is-authorized: true,
        certification: certification,
        institution: institution,
        training-date: stacks-block-height,
        samples-collected: u0
      }
    )
    (ok true)
  )
)

;; Read-only functions

;; Get pollen sample data
(define-read-only (get-pollen-sample (sample-id uint))
  (map-get? pollen-samples { sample-id: sample-id })
)

;; Get chemical analysis
(define-read-only (get-chemical-analysis (sample-id uint))
  (map-get? chemical-analysis { sample-id: sample-id })
)

;; Get health assessment
(define-read-only (get-health-assessment (assessment-id uint))
  (map-get? health-assessments { assessment-id: assessment-id })
)

;; Get exposure incident
(define-read-only (get-exposure-incident (incident-id uint))
  (map-get? exposure-incidents { incident-id: incident-id })
)

;; Get laboratory info
(define-read-only (get-laboratory (lab-id uint))
  (map-get? laboratory-certifications { lab-id: lab-id })
)

;; Get regional alert
(define-read-only (get-regional-alert (region-id uint))
  (map-get? regional-alerts { region-id: region-id })
)

;; Get total samples count
(define-read-only (get-total-samples)
  (var-get total-samples)
)

;; Get dangerous exposures count
(define-read-only (get-dangerous-exposures)
  (var-get dangerous-exposures)
)

;; Check if collector is authorized
(define-read-only (is-authorized-collector (collector principal))
  (default-to false
    (get is-authorized
      (map-get? authorized-collectors { collector: collector })
    )
  )
)

;; Check risk level by concentration
(define-read-only (assess-risk-level (concentration uint))
  (if (>= concentration danger-threshold)
    "dangerous"
    (if (>= concentration warning-threshold)
      "warning"
      "safe"
    )
  )
)

;; Private functions

;; Update collector statistics
(define-private (update-collector-stats (collector principal))
  (let 
    (
      (current-stats (default-to
        {
          is-authorized: true,
          certification: "",
          institution: "",
          training-date: u0,
          samples-collected: u0
        }
        (map-get? authorized-collectors { collector: collector })
      ))
    )
    (map-set authorized-collectors
      { collector: collector }
      (merge current-stats {
        samples-collected: (+ (get samples-collected current-stats) u1)
      })
    )
  )
)

;; Create regional alert for dangerous pesticide levels
(define-private (create-regional-alert (sample-data (tuple (collection-date uint) (collector principal) (lab-id uint) (location-lat int) (location-lon int) (plant-species (string-ascii 64)) (sample-weight uint) (status (string-ascii 32)))) (pesticide-name (string-ascii 64)) (concentration uint))
  (let ((region-id (to-uint (mod (get location-lat sample-data) 1000))))
    (map-set regional-alerts
      { region-id: region-id }
      {
        region-name: "Alert Region",
        alert-level: "high",
        pesticide-detected: pesticide-name,
        concentration: concentration,
        alert-date: stacks-block-height,
        expiry-date: (+ stacks-block-height u1440), ;; Alert expires in ~10 days
        affected-species: (get plant-species sample-data)
      }
    )
  )
)

