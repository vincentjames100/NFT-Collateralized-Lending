;; NFT Collateralized Lending Platform with Reputation System
;; Clarity 2.05 compatible smart contract

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-LOAN-ACTIVE (err u105))
(define-constant ERR-LOAN-EXPIRED (err u106))
(define-constant ERR-REPUTATION-TOO-LOW (err u107))
(define-constant ERR-INVALID-COLLATERAL (err u108))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Status constants
(define-constant STATUS-PENDING u0)
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-REPAID u2)
(define-constant STATUS-DEFAULTED u3)
(define-constant STATUS-CANCELLED u4)

;; Data structures
(define-map loans 
  { loan-id: uint }
  {
    borrower: principal,
    lender: principal,
    nft-contract: principal,
    nft-id: uint,
    loan-amount: uint,
    interest-rate: uint, ;; basis points (e.g., 500 = 5%)
    duration: uint, ;; in blocks
    start-block: uint,
    collateral-value: uint,
    status: uint ;; 0=pending, 1=active, 2=repaid, 3=defaulted
  })

(define-map user-reputation
  { user: principal }
  {
    total-loans: uint,
    successful-loans: uint,
    defaulted-loans: uint,
    reputation-score: uint, ;; 0-1000 scale
    last-activity: uint
  })

(define-map nft-collateral
  { nft-contract: principal, nft-id: uint }
  {
    loan-id: uint,
    locked: bool,
    valuation: uint,
    lock-time: uint
  })

;; Data variables
(define-data-var loan-counter uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points
(define-data-var min-reputation-score uint u500) ;; Minimum reputation for borrowing

;; Initialize user reputation for new users
(define-private (init-reputation (user principal))
  (match (map-get? user-reputation { user: user })
    existing-rep (ok existing-rep)
    (begin
      (map-set user-reputation
        { user: user }
        {
          total-loans: u0,
          successful-loans: u0,
          defaulted-loans: u0,
          reputation-score: u750, ;; Start with decent reputation
          last-activity: block-height
        })
      (ok {
        total-loans: u0,
        successful-loans: u0,
        defaulted-loans: u0,
        reputation-score: u750,
        last-activity: block-height
      }))))

;; Calculate reputation score based on loan history
(define-private (calculate-reputation-score (total-loans uint) (successful-loans uint) (defaulted-loans uint))
  (if (is-eq total-loans u0)
    u750 ;; Default score for new users
    (let ((success-rate (/ (* successful-loans u1000) total-loans))
          (default-penalty (if (> defaulted-loans u0) (/ (* defaulted-loans u200) total-loans) u0)))
      (if (>= success-rate default-penalty)
        (- success-rate default-penalty)
        u0))))

;; Update user reputation after loan completion
(define-private (update-reputation (user principal) (successful bool))
  (match (map-get? user-reputation { user: user })
    existing-rep
    (let ((new-total (+ (get total-loans existing-rep) u1))
          (new-successful (if successful (+ (get successful-loans existing-rep) u1) (get successful-loans existing-rep)))
          (new-defaulted (if successful (get defaulted-loans existing-rep) (+ (get defaulted-loans existing-rep) u1)))
          (new-score (calculate-reputation-score new-total new-successful new-defaulted)))
      (map-set user-reputation
        { user: user }
        {
          total-loans: new-total,
          successful-loans: new-successful,
          defaulted-loans: new-defaulted,
          reputation-score: new-score,
          last-activity: block-height
        })
      (ok new-score))
    ERR-NOT-FOUND))

;; Get user reputation (returns existing or creates new)
(define-public (get-user-reputation (user principal))
  (match (map-get? user-reputation { user: user })
    reputation (ok reputation)
    (init-reputation user)))

;; Read-only function to get existing reputation only
(define-read-only (get-existing-reputation (user principal))
  (map-get? user-reputation { user: user }))

;; Create a loan request (simplified version without NFT transfer)
(define-public (create-loan-request (nft-contract principal) (nft-id uint) (loan-amount uint) (interest-rate uint) (duration uint) (collateral-value uint))
  (let ((loan-id (+ (var-get loan-counter) u1))
        (borrower tx-sender))
    ;; Check borrower reputation
    (let ((reputation (unwrap-panic (get-user-reputation borrower))))
      (if (>= (get reputation-score reputation) (var-get min-reputation-score))
        (begin
          ;; Record collateral
          (map-set nft-collateral
            { nft-contract: nft-contract, nft-id: nft-id }
            {
              loan-id: loan-id,
              locked: true,
              valuation: collateral-value,
              lock-time: block-height
            })
          
          ;; Create loan entry
          (map-set loans
            { loan-id: loan-id }
            {
              borrower: borrower,
              lender: CONTRACT-OWNER, ;; Placeholder - will be set when funded
              nft-contract: nft-contract,
              nft-id: nft-id,
              loan-amount: loan-amount,
              interest-rate: interest-rate,
              duration: duration,
              start-block: u0, ;; Will be set when funded
              collateral-value: collateral-value,
              status: STATUS-PENDING
            })
          
          ;; Update counter
          (var-set loan-counter loan-id)
          (ok loan-id))
        ERR-REPUTATION-TOO-LOW))))

;; Fund a loan (lender provides the loan amount)
(define-public (fund-loan (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (if (is-eq (get status loan-data) STATUS-PENDING)
      (let ((loan-amount (get loan-amount loan-data))
            (lender tx-sender))
        ;; Transfer STX from lender to borrower
        (try! (stx-transfer? loan-amount lender (get borrower loan-data)))
        
        ;; Update loan with lender and start time
        (map-set loans
          { loan-id: loan-id }
          (merge loan-data {
            lender: lender,
            start-block: block-height,
            status: STATUS-ACTIVE
          }))
        
        (ok true))
      ERR-LOAN-ACTIVE)
    ERR-NOT-FOUND))

(define-public (cancel-loan-request (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (if (and (is-eq (get borrower loan-data) tx-sender)
             (is-eq (get status loan-data) STATUS-PENDING))
      (begin
        (map-set nft-collateral
          { nft-contract: (get nft-contract loan-data), nft-id: (get nft-id loan-data) }
          {
            loan-id: loan-id,
            locked: false,
            valuation: (get collateral-value loan-data),
            lock-time: u0
          })
        (map-set loans
          { loan-id: loan-id }
          (merge loan-data { status: STATUS-CANCELLED }))
        (ok true))
      ERR-UNAUTHORIZED)
    ERR-NOT-FOUND))

;; Repay loan
(define-public (repay-loan (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (if (and (is-eq (get borrower loan-data) tx-sender)
             (is-eq (get status loan-data) STATUS-ACTIVE))
      (let ((repay-amount (+ (get loan-amount loan-data) 
                             (/ (* (get loan-amount loan-data) (get interest-rate loan-data)) u10000)))
            (platform-fee (/ (* repay-amount (var-get platform-fee-rate)) u10000))
            (lender-amount (- repay-amount platform-fee)))
        
        ;; Transfer repayment to lender and fee to contract
        (try! (stx-transfer? lender-amount tx-sender (get lender loan-data)))
        (try! (stx-transfer? platform-fee tx-sender CONTRACT-OWNER))
        
        ;; Update collateral status (NFT release would happen off-chain)
        
        ;; Update collateral status
        (map-set nft-collateral
          { nft-contract: (get nft-contract loan-data), nft-id: (get nft-id loan-data) }
          {
            loan-id: loan-id,
            locked: false,
            valuation: (get collateral-value loan-data),
            lock-time: u0
          })
        
        ;; Update loan status
        (map-set loans
          { loan-id: loan-id }
          (merge loan-data { status: STATUS-REPAID }))
        
        ;; Update borrower reputation positively
        (try! (update-reputation (get borrower loan-data) true))
        
        (ok true))
      ERR-UNAUTHORIZED)
    ERR-NOT-FOUND))

;; Liquidate defaulted loan (after expiry)
(define-public (liquidate-loan (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (if (and (is-eq (get status loan-data) STATUS-ACTIVE)
             (> block-height (+ (get start-block loan-data) (get duration loan-data))))
      (begin
        ;; Update collateral status (NFT transfer would happen off-chain)
        
        ;; Update collateral status
        (map-set nft-collateral
          { nft-contract: (get nft-contract loan-data), nft-id: (get nft-id loan-data) }
          {
            loan-id: loan-id,
            locked: false,
            valuation: (get collateral-value loan-data),
            lock-time: u0
          })
        
        ;; Update loan status
        (map-set loans
          { loan-id: loan-id }
          (merge loan-data { status: STATUS-DEFAULTED }))
        
        ;; Update borrower reputation negatively
        (try! (update-reputation (get borrower loan-data) false))
        
        (ok true))
      ERR-LOAN-EXPIRED)
    ERR-NOT-FOUND))

;; Read-only functions
(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id }))

(define-read-only (get-collateral-info (nft-contract principal) (nft-id uint))
  (map-get? nft-collateral { nft-contract: nft-contract, nft-id: nft-id }))

(define-read-only (get-loan-counter)
  (var-get loan-counter))

(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate))

(define-read-only (get-min-reputation-score)
  (var-get min-reputation-score))

;; Admin functions (only contract owner)
(define-public (set-platform-fee-rate (new-rate uint))
  (if (is-eq tx-sender CONTRACT-OWNER)
    (begin
      (var-set platform-fee-rate new-rate)
      (ok true))
    ERR-UNAUTHORIZED))

(define-public (set-min-reputation-score (new-score uint))
  (if (is-eq tx-sender CONTRACT-OWNER)
    (begin
      (var-set min-reputation-score new-score)
      (ok true))
    ERR-UNAUTHORIZED))

;; Check if loan is expired
(define-read-only (is-loan-expired (loan-id uint))
  (match (map-get? loans { loan-id: loan-id })
    loan-data
    (if (is-eq (get status loan-data) STATUS-ACTIVE)
      (> block-height (+ (get start-block loan-data) (get duration loan-data)))
      false)
    false))

;; Get loan status as readable string
(define-read-only (get-loan-status-string (status uint))
  (if (is-eq status STATUS-PENDING)
    "pending"
    (if (is-eq status STATUS-ACTIVE)
      "active"
      (if (is-eq status STATUS-REPAID)
        "repaid"
        (if (is-eq status STATUS-DEFAULTED)
          "defaulted"
          (if (is-eq status STATUS-CANCELLED)
            "cancelled"
            "unknown"))))))
