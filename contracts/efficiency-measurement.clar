;; Efficiency Measurement Contract
;; Tracks waste reduction progress and efficiency metrics

(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_PERIOD (err u401))
(define-constant ERR_MEASUREMENT_NOT_FOUND (err u402))

;; Data structures
(define-map efficiency-measurements
  { facility-id: uint, period: uint }
  {
    total-production: uint,
    total-waste-generated: uint,
    total-waste-recycled: uint,
    energy-consumed: uint,
    water-used: uint,
    efficiency-score: uint,
    measurement-date: uint,
    reporter: principal
  }
)

(define-map efficiency-targets
  { facility-id: uint }
  {
    waste-reduction-target: uint, ;; percentage
    recycling-target: uint, ;; percentage
    energy-efficiency-target: uint,
    target-period: uint,
    set-date: uint
  }
)

(define-map efficiency-achievements
  { facility-id: uint, achievement-type: (string-ascii 50) }
  {
    achieved-date: uint,
    achievement-value: uint,
    verified: bool,
    reward-issued: bool
  }
)

;; Record efficiency measurement
(define-public (record-efficiency
  (facility-id uint)
  (period uint)
  (total-production uint)
  (total-waste-generated uint)
  (total-waste-recycled uint)
  (energy-consumed uint)
  (water-used uint))
  (let (
    (waste-ratio (if (> total-production u0) (/ (* total-waste-generated u100) total-production) u0))
    (recycling-ratio (if (> total-waste-generated u0) (/ (* total-waste-recycled u100) total-waste-generated) u0))
    (efficiency-score (calculate-efficiency-score waste-ratio recycling-ratio energy-consumed))
  )
    (map-set efficiency-measurements
      { facility-id: facility-id, period: period }
      {
        total-production: total-production,
        total-waste-generated: total-waste-generated,
        total-waste-recycled: total-waste-recycled,
        energy-consumed: energy-consumed,
        water-used: water-used,
        efficiency-score: efficiency-score,
        measurement-date: block-height,
        reporter: tx-sender
      }
    )
    (ok efficiency-score)
  )
)

;; Set efficiency targets
(define-public (set-efficiency-targets
  (facility-id uint)
  (waste-reduction-target uint)
  (recycling-target uint)
  (energy-efficiency-target uint)
  (target-period uint))
  (begin
    (map-set efficiency-targets
      { facility-id: facility-id }
      {
        waste-reduction-target: waste-reduction-target,
        recycling-target: recycling-target,
        energy-efficiency-target: energy-efficiency-target,
        target-period: target-period,
        set-date: block-height
      }
    )
    (ok true)
  )
)

;; Record achievement
(define-public (record-achievement
  (facility-id uint)
  (achievement-type (string-ascii 50))
  (achievement-value uint))
  (begin
    (map-set efficiency-achievements
      { facility-id: facility-id, achievement-type: achievement-type }
      {
        achieved-date: block-height,
        achievement-value: achievement-value,
        verified: false,
        reward-issued: false
      }
    )
    (ok true)
  )
)

;; Helper function to calculate efficiency score
(define-private (calculate-efficiency-score (waste-ratio uint) (recycling-ratio uint) (energy-consumed uint))
  (let (
    (waste-score (if (<= waste-ratio u10) u40 (if (<= waste-ratio u20) u30 u10)))
    (recycling-score (if (>= recycling-ratio u80) u40 (if (>= recycling-ratio u60) u30 u20)))
    (energy-score (if (<= energy-consumed u1000) u20 u10))
  )
    (+ waste-score recycling-score energy-score)
  )
)

;; Read-only functions
(define-read-only (get-efficiency-measurement (facility-id uint) (period uint))
  (map-get? efficiency-measurements { facility-id: facility-id, period: period })
)

(define-read-only (get-efficiency-targets (facility-id uint))
  (map-get? efficiency-targets { facility-id: facility-id })
)

(define-read-only (get-achievement (facility-id uint) (achievement-type (string-ascii 50)))
  (map-get? efficiency-achievements { facility-id: facility-id, achievement-type: achievement-type })
)

(define-read-only (calculate-waste-reduction-percentage (facility-id uint) (current-period uint) (previous-period uint))
  (match (map-get? efficiency-measurements { facility-id: facility-id, period: current-period })
    current-data
    (match (map-get? efficiency-measurements { facility-id: facility-id, period: previous-period })
      previous-data
      (let (
        (current-waste-ratio (/ (* (get total-waste-generated current-data) u100) (get total-production current-data)))
        (previous-waste-ratio (/ (* (get total-waste-generated previous-data) u100) (get total-production previous-data)))
      )
        (if (> previous-waste-ratio u0)
          (ok (/ (* (- previous-waste-ratio current-waste-ratio) u100) previous-waste-ratio))
          (ok u0)
        )
      )
      ERR_MEASUREMENT_NOT_FOUND
    )
    ERR_MEASUREMENT_NOT_FOUND
  )
)
