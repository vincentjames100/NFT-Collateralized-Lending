(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_LOAN_NOT_FOUND (err u101))
(define-constant ERR_LOAN_ALREADY_EXISTS (err u102))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u103))
(define-constant ERR_LOAN_EXPIRED (err u104))
(define-constant ERR_INVALID_AMOUNT (err u105))
(define-constant ERR_NFT_NOT_OWNED (err u106))
(define-constant ERR_PAYMENT_FAILED (err u107))
(define-constant ERR_LIQUIDATION_FAILED (err u108))
(define-constant ERR_INVALID_ORACLE_PRICE (err u109))
(define-constant ERR_TRANSFER_FAILED (err u110))

(define-constant LOAN_DURATION u144)
(define-constant LIQUIDATION_THRESHOLD u75)
(define-constant INTEREST_RATE u5)
(define-constant AUCTION_DURATION u12)
(define-constant EXTENSION_DURATION u144)
(define-constant EXTENSION_FEE_RATE u3)

(define-data-var loan-id-nonce uint u0)
(define-data-var auction-id-nonce uint u0)
(define-data-var total-loans-active uint u0)
(define-data-var total-volume uint u0)

(define-trait nft-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (get-owner (uint) (response (optional principal) uint))
  )
)

(define-map loans
  uint
  {
    borrower: principal,
    nft-contract: principal,
    nft-id: uint,
    loan-amount: uint,
    collateral-value: uint,
    interest-amount: uint,
    start-block: uint,
    due-block: uint,
    extensions-count: uint,
    status: (string-ascii 20)
  }
)

(define-map nft-prices
  { contract: principal, token-id: uint }
  { price: uint, last-updated: uint }
)

(define-map auctions
  uint
  {
    loan-id: uint,
    nft-contract: principal,
    nft-id: uint,
    starting-price: uint,
    current-bid: uint,
    highest-bidder: (optional principal),
    end-block: uint,
    status: (string-ascii 20)
  }
)

(define-map user-loans principal (list 50 uint))

(define-public (create-loan (nft-contract <nft-trait>) (nft-id uint) (loan-amount uint))
  (let
    (
      (current-loan-id (+ (var-get loan-id-nonce) u1))
      (nft-price (get-nft-price (contract-of nft-contract) nft-id))
      (required-collateral (* loan-amount u133))
      (interest (/ (* loan-amount INTEREST_RATE) u100))
      (current-block stacks-block-height)
      (due-block (+ current-block LOAN_DURATION))
    )
    (asserts! (> loan-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= (* nft-price u100) required-collateral) ERR_INSUFFICIENT_COLLATERAL)
    (asserts! (is-none (map-get? loans current-loan-id)) ERR_LOAN_ALREADY_EXISTS)
    
    (try! (contract-call? nft-contract transfer nft-id tx-sender (as-contract tx-sender)))
    
    (map-set loans current-loan-id
      {
        borrower: tx-sender,
        nft-contract: (contract-of nft-contract),
        nft-id: nft-id,
        loan-amount: loan-amount,
        collateral-value: nft-price,
        interest-amount: interest,
        start-block: current-block,
        due-block: due-block,
        extensions-count: u0,
        status: "active"
      }
    )
    
    (let ((user-loan-list (default-to (list) (map-get? user-loans tx-sender))))
      (map-set user-loans tx-sender (unwrap! (as-max-len? (append user-loan-list current-loan-id) u50) ERR_INVALID_AMOUNT))
    )
    
    (var-set loan-id-nonce current-loan-id)
    (var-set total-loans-active (+ (var-get total-loans-active) u1))
    (var-set total-volume (+ (var-get total-volume) loan-amount))
    
    (try! (as-contract (stx-transfer? loan-amount tx-sender tx-sender)))
    (ok current-loan-id)
  )
)

(define-public (repay-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
      (total-repayment (+ (get loan-amount loan) (get interest-amount loan)))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status loan) "active") ERR_LOAN_NOT_FOUND)
    
    (try! (stx-transfer? total-repayment tx-sender (as-contract tx-sender)))
    
    (map-set loans loan-id (merge loan { status: "repaid" }))
    (var-set total-loans-active (- (var-get total-loans-active) u1))
    (ok true)
  )
)

(define-public (liquidate-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
      (current-block stacks-block-height)
      (current-price (get-nft-price (get nft-contract loan) (get nft-id loan)))
      (loan-value (+ (get loan-amount loan) (get interest-amount loan)))
      (collateral-ratio (/ (* current-price u100) loan-value))
    )
    (asserts! (is-eq (get status loan) "active") ERR_LOAN_NOT_FOUND)
    (asserts! (or 
                (>= current-block (get due-block loan))
                (<= collateral-ratio LIQUIDATION_THRESHOLD)
              ) ERR_NOT_AUTHORIZED)
    
    (map-set loans loan-id (merge loan { status: "liquidated" }))
    (var-set total-loans-active (- (var-get total-loans-active) u1))
    (try! (start-auction loan-id))
    (ok true)
  )
)

(define-public (start-auction (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
      (current-auction-id (+ (var-get auction-id-nonce) u1))
      (starting-price (/ (* (get collateral-value loan) u80) u100))
      (end-block (+ stacks-block-height AUCTION_DURATION))
    )
    (asserts! (is-eq (get status loan) "liquidated") ERR_NOT_AUTHORIZED)
    
    (map-set auctions current-auction-id
      {
        loan-id: loan-id,
        nft-contract: (get nft-contract loan),
        nft-id: (get nft-id loan),
        starting-price: starting-price,
        current-bid: u0,
        highest-bidder: none,
        end-block: end-block,
        status: "active"
      }
    )
    
    (var-set auction-id-nonce current-auction-id)
    (ok current-auction-id)
  )
)

(define-public (place-bid (auction-id uint) (bid-amount uint))
  (let
    (
      (auction (unwrap! (map-get? auctions auction-id) ERR_LOAN_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq (get status auction) "active") ERR_NOT_AUTHORIZED)
    (asserts! (< current-block (get end-block auction)) ERR_LOAN_EXPIRED)
    (asserts! (> bid-amount (get current-bid auction)) ERR_INVALID_AMOUNT)
    (asserts! (>= bid-amount (get starting-price auction)) ERR_INVALID_AMOUNT)
    
    (if (is-some (get highest-bidder auction))
      (try! (as-contract (stx-transfer? (get current-bid auction) tx-sender (unwrap-panic (get highest-bidder auction)))))
      false
    )
    
    (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
    
    (map-set auctions auction-id (merge auction
      {
        current-bid: bid-amount,
        highest-bidder: (some tx-sender)
      }
    ))
    (ok true)
  )
)

(define-public (finalize-auction (auction-id uint))
  (let
    (
      (auction (unwrap! (map-get? auctions auction-id) ERR_LOAN_NOT_FOUND))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq (get status auction) "active") ERR_NOT_AUTHORIZED)
    (asserts! (>= current-block (get end-block auction)) ERR_NOT_AUTHORIZED)
    
    (if (is-some (get highest-bidder auction))
      (begin
        (map-set auctions auction-id (merge auction { status: "completed" }))
        (ok true)
      )
      (begin
        (map-set auctions auction-id (merge auction { status: "failed" }))
        (ok false)
      )
    )
  )
)

(define-public (update-nft-price (nft-contract principal) (nft-id uint) (price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> price u0) ERR_INVALID_ORACLE_PRICE)
    (map-set nft-prices { contract: nft-contract, token-id: nft-id }
      { price: price, last-updated: stacks-block-height }
    )
    (ok true)
  )
)

(define-public (extend-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
      (extension-fee (/ (* (get loan-amount loan) EXTENSION_FEE_RATE) u100))
      (new-due-block (+ (get due-block loan) EXTENSION_DURATION))
      (new-extensions-count (+ (get extensions-count loan) u1))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status loan) "active") ERR_LOAN_NOT_FOUND)
    (asserts! (< (get extensions-count loan) u3) ERR_NOT_AUTHORIZED)
    (asserts! (> stacks-block-height (- (get due-block loan) u24)) ERR_NOT_AUTHORIZED)
    
    (try! (stx-transfer? extension-fee tx-sender (as-contract tx-sender)))
    
    (map-set loans loan-id (merge loan
      {
        due-block: new-due-block,
        extensions-count: new-extensions-count
      }
    ))
    (ok true)
  )
)

(define-public (emergency-withdraw (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) ERR_LOAN_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set loans loan-id (merge loan { status: "withdrawn" }))
    (ok true)
  )
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)

(define-read-only (get-auction (auction-id uint))
  (map-get? auctions auction-id)
)

(define-read-only (get-user-loans (user principal))
  (default-to (list) (map-get? user-loans user))
)

(define-read-only (get-nft-price (nft-contract principal) (nft-id uint))
  (default-to u1000000 (get price (map-get? nft-prices { contract: nft-contract, token-id: nft-id })))
)

(define-read-only (calculate-interest (loan-amount uint) (blocks-elapsed uint))
  (/ (* (* loan-amount INTEREST_RATE) blocks-elapsed) (* u100 u144))
)

(define-read-only (get-loan-health (loan-id uint))
  (match (map-get? loans loan-id)
    loan (let
      (
        (current-price (get-nft-price (get nft-contract loan) (get nft-id loan)))
        (loan-value (+ (get loan-amount loan) (get interest-amount loan)))
      )
      (some (/ (* current-price u100) loan-value))
    )
    none
  )
)

(define-read-only (get-contract-stats)
  {
    total-loans: (var-get total-loans-active),
    total-volume: (var-get total-volume),
    loan-count: (var-get loan-id-nonce),
    auction-count: (var-get auction-id-nonce)
  }
)

(define-read-only (is-loan-liquidatable (loan-id uint))
  (match (map-get? loans loan-id)
    loan (let
      (
        (current-block stacks-block-height)
        (health-ratio (unwrap! (get-loan-health loan-id) false))
      )
      (or 
        (>= current-block (get due-block loan))
        (<= health-ratio LIQUIDATION_THRESHOLD)
      )
    )
    false
  )
)

(define-read-only (get-active-auctions)
  (filter is-auction-active (list
    u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
    u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
  ))
)

(define-private (is-auction-active (auction-id uint))
  (match (map-get? auctions auction-id)
    auction (is-eq (get status auction) "active")
    false
  )
)

(define-read-only (get-liquidatable-loans)
  (filter is-loan-liquidatable-helper (list
    u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
    u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
  ))
)

(define-private (is-loan-liquidatable-helper (loan-id uint))
  (is-loan-liquidatable loan-id)
)

(define-read-only (get-extension-cost (loan-id uint))
  (match (map-get? loans loan-id)
    loan (let
      (
        (extension-fee (/ (* (get loan-amount loan) EXTENSION_FEE_RATE) u100))
      )
      (some extension-fee)
    )
    none
  )
)

(define-read-only (can-extend-loan (loan-id uint))
  (match (map-get? loans loan-id)
    loan (let
      (
        (current-block stacks-block-height)
        (blocks-until-due (- (get due-block loan) current-block))
      )
      (and
        (is-eq (get status loan) "active")
        (< (get extensions-count loan) u3)
        (<= blocks-until-due u24)
      )
    )
    false
  )
)
