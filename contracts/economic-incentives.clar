;; Economic Development Incentive Tracking Contract
;; Monitors tax incentives and business development programs

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INCENTIVE-NOT-FOUND (err u301))
(define-constant ERR-BUSINESS-NOT-FOUND (err u302))
(define-constant ERR-INVALID-INPUT (err u303))
(define-constant ERR-ALREADY-CLAIMED (err u304))
(define-constant ERR-NOT-ELIGIBLE (err u305))

;; Data Variables
(define-data-var next-incentive-id uint u1)
(define-data-var next-application-id uint u1)
(define-data-var contract-admin principal CONTRACT-OWNER)
(define-data-var total-incentives-awarded uint u0)

;; Data Maps
(define-map incentive-programs
  { incentive-id: uint }
  {
    program-name: (string-ascii 100),
    description: (string-ascii 300),
    incentive-type: (string-ascii 50), ;; "tax-credit", "rebate", "grant", "loan-forgiveness"
    amount: uint,
    eligibility-criteria: (string-ascii 500),
    application-deadline: uint,
    max-awards: uint,
    current-awards: uint,
    is-active: bool,
    created-date: uint
  }
)

(define-map incentive-applications
  { application-id: uint }
  {
    business-principal: principal,
    incentive-id: uint,
    business-name: (string-ascii 100),
    application-date: uint,
    status: (string-ascii 20), ;; "pending", "approved", "denied", "awarded"
    review-date: uint,
    award-date: uint,
    compliance-status: (string-ascii 20),
    jobs-created: uint,
    investment-amount: uint,
    supporting-documents: (string-ascii 200)
  }
)

(define-map business-profiles
  { business-principal: principal }
  {
    business-name: (string-ascii 100),
    industry: (string-ascii 50),
    location: (string-ascii 100),
    employees-before: uint,
    employees-current: uint,
    annual-revenue: uint,
    years-in-operation: uint,
    is-minority-owned: bool,
    is-veteran-owned: bool,
    registration-date: uint
  }
)

(define-map compliance-reports
  { application-id: uint, report-period: uint }
  {
    jobs-maintained: uint,
    new-jobs-created: uint,
    investment-completed: uint,
    revenue-impact: uint,
    report-date: uint,
    compliance-score: uint,
    notes: (string-ascii 300)
  }
)

(define-map economic-impact-metrics
  { period: uint }
  {
    total-jobs-created: uint,
    total-investment-attracted: uint,
    total-incentives-awarded: uint,
    businesses-supported: uint,
    average-wage-increase: uint,
    tax-revenue-generated: uint
  }
)

;; Public Functions

;; Create new incentive program
(define-public (create-incentive-program (program-name (string-ascii 100)) (description (string-ascii 300)) (incentive-type (string-ascii 50)) (amount uint) (eligibility-criteria (string-ascii 500)) (application-deadline uint) (max-awards uint))
  (let
    (
      (incentive-id (var-get next-incentive-id))
    )
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len program-name) u0) ERR-INVALID-INPUT)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (> max-awards u0) ERR-INVALID-INPUT)

    (map-set incentive-programs
      { incentive-id: incentive-id }
      {
        program-name: program-name,
        description: description,
        incentive-type: incentive-type,
        amount: amount,
        eligibility-criteria: eligibility-criteria,
        application-deadline: application-deadline,
        max-awards: max-awards,
        current-awards: u0,
        is-active: true,
        created-date: block-height
      }
    )

    (var-set next-incentive-id (+ incentive-id u1))
    (ok incentive-id)
  )
)

;; Register business profile
(define-public (register-business-profile (business-name (string-ascii 100)) (industry (string-ascii 50)) (location (string-ascii 100)) (employees-before uint) (annual-revenue uint) (years-in-operation uint) (is-minority-owned bool) (is-veteran-owned bool))
  (begin
    (asserts! (> (len business-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len industry) u0) ERR-INVALID-INPUT)

    (map-set business-profiles
      { business-principal: tx-sender }
      {
        business-name: business-name,
        industry: industry,
        location: location,
        employees-before: employees-before,
        employees-current: employees-before,
        annual-revenue: annual-revenue,
        years-in-operation: years-in-operation,
        is-minority-owned: is-minority-owned,
        is-veteran-owned: is-veteran-owned,
        registration-date: block-height
      }
    )

    (ok true)
  )
)

;; Apply for incentive
(define-public (apply-for-incentive (incentive-id uint) (jobs-created uint) (investment-amount uint) (supporting-documents (string-ascii 200)))
  (let
    (
      (application-id (var-get next-application-id))
      (incentive (unwrap! (map-get? incentive-programs { incentive-id: incentive-id }) ERR-INCENTIVE-NOT-FOUND))
      (business (unwrap! (map-get? business-profiles { business-principal: tx-sender }) ERR-BUSINESS-NOT-FOUND))
    )
    (asserts! (get is-active incentive) ERR-NOT-ELIGIBLE)
    (asserts! (< (get current-awards incentive) (get max-awards incentive)) ERR-NOT-ELIGIBLE)
    (asserts! (<= block-height (get application-deadline incentive)) ERR-NOT-ELIGIBLE)

    (map-set incentive-applications
      { application-id: application-id }
      {
        business-principal: tx-sender,
        incentive-id: incentive-id,
        business-name: (get business-name business),
        application-date: block-height,
        status: "pending",
        review-date: u0,
        award-date: u0,
        compliance-status: "pending",
        jobs-created: jobs-created,
        investment-amount: investment-amount,
        supporting-documents: supporting-documents
      }
    )

    (var-set next-application-id (+ application-id u1))
    (ok application-id)
  )
)

;; Review and approve incentive application
(define-public (review-application (application-id uint) (approved bool))
  (let
    (
      (application (unwrap! (map-get? incentive-applications { application-id: application-id }) ERR-INCENTIVE-NOT-FOUND))
      (incentive (unwrap! (map-get? incentive-programs { incentive-id: (get incentive-id application) }) ERR-INCENTIVE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status application) "pending") ERR-INVALID-INPUT)

    (if approved
      (begin
        ;; Approve application
        (map-set incentive-applications
          { application-id: application-id }
          (merge application {
            status: "approved",
            review-date: block-height
          })
        )

        ;; Update incentive program award count
        (map-set incentive-programs
          { incentive-id: (get incentive-id application) }
          (merge incentive {
            current-awards: (+ (get current-awards incentive) u1)
          })
        )
      )
      ;; Deny application
      (map-set incentive-applications
        { application-id: application-id }
        (merge application {
          status: "denied",
          review-date: block-height
        })
      )
    )

    (ok true)
  )
)

;; Award incentive
(define-public (award-incentive (application-id uint))
  (let
    (
      (application (unwrap! (map-get? incentive-applications { application-id: application-id }) ERR-INCENTIVE-NOT-FOUND))
      (incentive (unwrap! (map-get? incentive-programs { incentive-id: (get incentive-id application) }) ERR-INCENTIVE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status application) "approved") ERR-INVALID-INPUT)

    (map-set incentive-applications
      { application-id: application-id }
      (merge application {
        status: "awarded",
        award-date: block-height,
        compliance-status: "monitoring"
      })
    )

    ;; Update total incentives awarded
    (var-set total-incentives-awarded (+ (var-get total-incentives-awarded) (get amount incentive)))

    (ok true)
  )
)

;; Submit compliance report
(define-public (submit-compliance-report (application-id uint) (report-period uint) (jobs-maintained uint) (new-jobs-created uint) (investment-completed uint) (revenue-impact uint) (notes (string-ascii 300)))
  (let
    (
      (application (unwrap! (map-get? incentive-applications { application-id: application-id }) ERR-INCENTIVE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get business-principal application)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status application) "awarded") ERR-INVALID-INPUT)

    (map-set compliance-reports
      { application-id: application-id, report-period: report-period }
      {
        jobs-maintained: jobs-maintained,
        new-jobs-created: new-jobs-created,
        investment-completed: investment-completed,
        revenue-impact: revenue-impact,
        report-date: block-height,
        compliance-score: (if (and (>= jobs-maintained (get jobs-created application)) (>= investment-completed (get investment-amount application))) u100 u50),
        notes: notes
      }
    )

    (ok true)
  )
)

;; Update economic impact metrics
(define-public (update-economic-metrics (period uint) (total-jobs-created uint) (total-investment-attracted uint) (businesses-supported uint) (average-wage-increase uint) (tax-revenue-generated uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) ERR-NOT-AUTHORIZED)

    (map-set economic-impact-metrics
      { period: period }
      {
        total-jobs-created: total-jobs-created,
        total-investment-attracted: total-investment-attracted,
        total-incentives-awarded: (var-get total-incentives-awarded),
        businesses-supported: businesses-supported,
        average-wage-increase: average-wage-increase,
        tax-revenue-generated: tax-revenue-generated
      }
    )

    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-incentive-program (incentive-id uint))
  (map-get? incentive-programs { incentive-id: incentive-id })
)

(define-read-only (get-incentive-application (application-id uint))
  (map-get? incentive-applications { application-id: application-id })
)

(define-read-only (get-business-profile (business-principal principal))
  (map-get? business-profiles { business-principal: business-principal })
)

(define-read-only (get-compliance-report (application-id uint) (report-period uint))
  (map-get? compliance-reports { application-id: application-id, report-period: report-period })
)

(define-read-only (get-economic-metrics (period uint))
  (map-get? economic-impact-metrics { period: period })
)

(define-read-only (get-total-incentives-awarded)
  (var-get total-incentives-awarded)
)
