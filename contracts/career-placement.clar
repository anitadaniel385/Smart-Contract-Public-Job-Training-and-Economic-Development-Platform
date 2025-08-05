;; Career Placement Services Contract
;; Connects job seekers with employment opportunities

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-JOB-NOT-FOUND (err u401))
(define-constant ERR-SEEKER-NOT-FOUND (err u402))
(define-constant ERR-INVALID-INPUT (err u403))
(define-constant ERR-APPLICATION-EXISTS (err u404))
(define-constant ERR-JOB-FILLED (err u405))

;; Data Variables
(define-data-var next-job-id uint u1)
(define-data-var next-seeker-id uint u1)
(define-data-var next-application-id uint u1)
(define-data-var contract-admin principal CONTRACT-OWNER)

;; Data Maps
(define-map job-postings
  { job-id: uint }
  {
    employer: principal,
    job-title: (string-ascii 100),
    description: (string-ascii 500),
    salary: uint,
    location: (string-ascii 100),
    employment-type: (string-ascii 20), ;; "full-time", "part-time", "contract", "temporary"
    required-skills: (string-ascii 300),
    experience-level: (string-ascii 20), ;; "entry", "mid", "senior", "executive"
    posting-date: uint,
    application-deadline: uint,
    is-active: bool,
    positions-available: uint,
    positions-filled: uint
  }
)

(define-map job-seekers
  { seeker-id: uint }
  {
    seeker-principal: principal,
    full-name: (string-ascii 100),
    email: (string-ascii 100),
    phone: (string-ascii 20),
    location: (string-ascii 100),
    skills: (string-ascii 300),
    experience-years: uint,
    education-level: (string-ascii 50),
    desired-salary: uint,
    employment-status: (string-ascii 20), ;; "unemployed", "employed", "seeking"
    registration-date: uint,
    is-active: bool
  }
)

(define-map job-applications
  { application-id: uint }
  {
    job-id: uint,
    seeker-id: uint,
    application-date: uint,
    status: (string-ascii 20), ;; "submitted", "reviewed", "interviewed", "offered", "hired", "rejected"
    cover-letter: (string-ascii 500),
    resume-hash: (string-ascii 64),
    interview-date: uint,
    interview-notes: (string-ascii 300),
    offer-amount: uint,
    start-date: uint
  }
)

(define-map employer-profiles
  { employer: principal }
  {
    company-name: (string-ascii 100),
    industry: (string-ascii 50),
    company-size: uint,
    location: (string-ascii 100),
    contact-person: (string-ascii 100),
    contact-email: (string-ascii 100),
    registration-date: uint,
    is-verified: bool,
    jobs-posted: uint,
    successful-hires: uint
  }
)

(define-map placement-outcomes
  { application-id: uint }
  {
    hire-date: uint,
    starting-salary: uint,
    job-satisfaction-score: uint,
    retention-period: uint,
    promotion-received: bool,
    salary-increase: uint,
    feedback: (string-ascii 300)
  }
)

;; Public Functions

;; Register as job seeker
(define-public (register-job-seeker (full-name (string-ascii 100)) (email (string-ascii 100)) (phone (string-ascii 20)) (location (string-ascii 100)) (skills (string-ascii 300)) (experience-years uint) (education-level (string-ascii 50)) (desired-salary uint))
  (let
    (
      (seeker-id (var-get next-seeker-id))
    )
    (asserts! (> (len full-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len email) u0) ERR-INVALID-INPUT)
    (asserts! (> (len skills) u0) ERR-INVALID-INPUT)

    (map-set job-seekers
      { seeker-id: seeker-id }
      {
        seeker-principal: tx-sender,
        full-name: full-name,
        email: email,
        phone: phone,
        location: location,
        skills: skills,
        experience-years: experience-years,
        education-level: education-level,
        desired-salary: desired-salary,
        employment-status: "seeking",
        registration-date: block-height,
        is-active: true
      }
    )

    (var-set next-seeker-id (+ seeker-id u1))
    (ok seeker-id)
  )
)

;; Register employer profile
(define-public (register-employer (company-name (string-ascii 100)) (industry (string-ascii 50)) (company-size uint) (location (string-ascii 100)) (contact-person (string-ascii 100)) (contact-email (string-ascii 100)))
  (begin
    (asserts! (> (len company-name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len industry) u0) ERR-INVALID-INPUT)

    (map-set employer-profiles
      { employer: tx-sender }
      {
        company-name: company-name,
        industry: industry,
        company-size: company-size,
        location: location,
        contact-person: contact-person,
        contact-email: contact-email,
        registration-date: block-height,
        is-verified: false,
        jobs-posted: u0,
        successful-hires: u0
      }
    )

    (ok true)
  )
)

;; Post job opportunity
(define-public (post-job (job-title (string-ascii 100)) (description (string-ascii 500)) (salary uint) (location (string-ascii 100)) (employment-type (string-ascii 20)) (required-skills (string-ascii 300)) (experience-level (string-ascii 20)) (application-deadline uint) (positions-available uint))
  (let
    (
      (job-id (var-get next-job-id))
      (employer (unwrap! (map-get? employer-profiles { employer: tx-sender }) ERR-NOT-AUTHORIZED))
    )
    (asserts! (> (len job-title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> salary u0) ERR-INVALID-INPUT)
    (asserts! (> positions-available u0) ERR-INVALID-INPUT)

    (map-set job-postings
      { job-id: job-id }
      {
        employer: tx-sender,
        job-title: job-title,
        description: description,
        salary: salary,
        location: location,
        employment-type: employment-type,
        required-skills: required-skills,
        experience-level: experience-level,
        posting-date: block-height,
        application-deadline: application-deadline,
        is-active: true,
        positions-available: positions-available,
        positions-filled: u0
      }
    )

    ;; Update employer job count
    (map-set employer-profiles
      { employer: tx-sender }
      (merge employer {
        jobs-posted: (+ (get jobs-posted employer) u1)
      })
    )

    (var-set next-job-id (+ job-id u1))
    (ok job-id)
  )
)

;; Apply for job
(define-public (apply-for-job (job-id uint) (seeker-id uint) (cover-letter (string-ascii 500)) (resume-hash (string-ascii 64)))
  (let
    (
      (application-id (var-get next-application-id))
      (job (unwrap! (map-get? job-postings { job-id: job-id }) ERR-JOB-NOT-FOUND))
      (seeker (unwrap! (map-get? job-seekers { seeker-id: seeker-id }) ERR-SEEKER-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get seeker-principal seeker)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active job) ERR-JOB-NOT-FOUND)
    (asserts! (<= block-height (get application-deadline job)) ERR-INVALID-INPUT)
    (asserts! (< (get positions-filled job) (get positions-available job)) ERR-JOB-FILLED)

    (map-set job-applications
      { application-id: application-id }
      {
        job-id: job-id,
        seeker-id: seeker-id,
        application-date: block-height,
        status: "submitted",
        cover-letter: cover-letter,
        resume-hash: resume-hash,
        interview-date: u0,
        interview-notes: "",
        offer-amount: u0,
        start-date: u0
      }
    )

    (var-set next-application-id (+ application-id u1))
    (ok application-id)
  )
)

;; Update application status
(define-public (update-application-status (application-id uint) (new-status (string-ascii 20)) (interview-date uint) (interview-notes (string-ascii 300)) (offer-amount uint))
  (let
    (
      (application (unwrap! (map-get? job-applications { application-id: application-id }) ERR-JOB-NOT-FOUND))
      (job (unwrap! (map-get? job-postings { job-id: (get job-id application) }) ERR-JOB-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get employer job)) ERR-NOT-AUTHORIZED)

    (map-set job-applications
      { application-id: application-id }
      (merge application {
        status: new-status,
        interview-date: interview-date,
        interview-notes: interview-notes,
        offer-amount: offer-amount
      })
    )

    (ok true)
  )
)

;; Hire candidate
(define-public (hire-candidate (application-id uint) (start-date uint) (starting-salary uint))
  (let
    (
      (application (unwrap! (map-get? job-applications { application-id: application-id }) ERR-JOB-NOT-FOUND))
      (job (unwrap! (map-get? job-postings { job-id: (get job-id application) }) ERR-JOB-NOT-FOUND))
      (seeker (unwrap! (map-get? job-seekers { seeker-id: (get seeker-id application) }) ERR-SEEKER-NOT-FOUND))
      (employer (unwrap! (map-get? employer-profiles { employer: tx-sender }) ERR-NOT-AUTHORIZED))
    )
    (asserts! (is-eq tx-sender (get employer job)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status application) "offered") ERR-INVALID-INPUT)

    ;; Update application status
    (map-set job-applications
      { application-id: application-id }
      (merge application {
        status: "hired",
        start-date: start-date
      })
    )

    ;; Update job posting
    (map-set job-postings
      { job-id: (get job-id application) }
      (merge job {
        positions-filled: (+ (get positions-filled job) u1)
      })
    )

    ;; Update seeker employment status
    (map-set job-seekers
      { seeker-id: (get seeker-id application) }
      (merge seeker {
        employment-status: "employed"
      })
    )

    ;; Update employer successful hires
    (map-set employer-profiles
      { employer: tx-sender }
      (merge employer {
        successful-hires: (+ (get successful-hires employer) u1)
      })
    )

    ;; Record placement outcome
    (map-set placement-outcomes
      { application-id: application-id }
      {
        hire-date: start-date,
        starting-salary: starting-salary,
        job-satisfaction-score: u0,
        retention-period: u0,
        promotion-received: false,
        salary-increase: u0,
        feedback: ""
      }
    )

    (ok true)
  )
)

;; Update placement outcome
(define-public (update-placement-outcome (application-id uint) (job-satisfaction-score uint) (retention-period uint) (promotion-received bool) (salary-increase uint) (feedback (string-ascii 300)))
  (let
    (
      (outcome (unwrap! (map-get? placement-outcomes { application-id: application-id }) ERR-JOB-NOT-FOUND))
      (application (unwrap! (map-get? job-applications { application-id: application-id }) ERR-JOB-NOT-FOUND))
      (seeker (unwrap! (map-get? job-seekers { seeker-id: (get seeker-id application) }) ERR-SEEKER-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get seeker-principal seeker)) ERR-NOT-AUTHORIZED)
    (asserts! (<= job-satisfaction-score u10) ERR-INVALID-INPUT)

    (map-set placement-outcomes
      { application-id: application-id }
      (merge outcome {
        job-satisfaction-score: job-satisfaction-score,
        retention-period: retention-period,
        promotion-received: promotion-received,
        salary-increase: salary-increase,
        feedback: feedback
      })
    )

    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-job-posting (job-id uint))
  (map-get? job-postings { job-id: job-id })
)

(define-read-only (get-job-seeker (seeker-id uint))
  (map-get? job-seekers { seeker-id: seeker-id })
)

(define-read-only (get-job-application (application-id uint))
  (map-get? job-applications { application-id: application-id })
)

(define-read-only (get-employer-profile (employer principal))
  (map-get? employer-profiles { employer: employer })
)

(define-read-only (get-placement-outcome (application-id uint))
  (map-get? placement-outcomes { application-id: application-id })
)

(define-read-only (get-next-job-id)
  (var-get next-job-id)
)

(define-read-only (get-next-seeker-id)
  (var-get next-seeker-id)
)
