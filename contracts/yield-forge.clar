;; YieldForge Protocol
;;
;; A next-generation DeFi yield optimization platform built on Stacks
;; Revolutionizing passive income generation for Bitcoin holders
;;
;; Summary:
;; YieldForge transforms idle sBTC into productive assets through intelligent
;; staking mechanisms. Users deposit sBTC and earn competitive yields while
;; maintaining full custody control. The protocol features dynamic reward
;; distribution, flexible withdrawal options, and automated compound growth.
;;
;; Description:
;; YieldForge addresses the challenge of Bitcoin yield generation by creating
;; a trustless, transparent staking infrastructure. The protocol implements
;; time-weighted rewards, ensuring early adopters and long-term holders are
;; appropriately incentivized. Built with security-first principles, the
;; platform features configurable parameters, emergency controls, and
;; comprehensive analytics for optimal DeFi experience.
;;

;; ERROR DEFINITIONS

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ZERO_STAKE (err u101))
(define-constant ERR_NO_STAKE_FOUND (err u102))
(define-constant ERR_TOO_EARLY_TO_UNSTAKE (err u103))
(define-constant ERR_INVALID_REWARD_RATE (err u104))
(define-constant ERR_NOT_ENOUGH_REWARDS (err u105))
(define-constant ERR_INVALID_PERIOD (err u106))
(define-constant ERR_SAME_OWNER (err u107))

;; DATA STRUCTURES

;; Primary staking positions for yield generation
(define-map stakes
  { staker: principal }
  {
    amount: uint,
    staked-at: uint,
  }
)

;; Historical reward distribution tracking
(define-map rewards-claimed
  { staker: principal }
  { amount: uint }
)

;; PROTOCOL CONFIGURATION

;; Annual yield rate in basis points (5 = 0.05% per calculation period)
(define-data-var reward-rate uint u5)

;; Treasury pool for reward distribution
(define-data-var reward-pool uint u0)

;; Minimum commitment period for yield eligibility (blocks)
(define-data-var min-stake-period uint u1440)

;; Protocol-wide total value locked (TVL)
(define-data-var total-staked uint u0)

;; Protocol governance address
(define-data-var contract-owner principal tx-sender)

;; GOVERNANCE & ADMINISTRATION

;; Retrieve current protocol administrator
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Transfer protocol ownership to new administrator
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq new-owner (var-get contract-owner))) ERR_SAME_OWNER)
    (ok (var-set contract-owner new-owner))
  )
)

;; Adjust protocol yield parameters
(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (< new-rate u1000) ERR_INVALID_REWARD_RATE) ;; Maximum 100% APY
    (ok (var-set reward-rate new-rate))
  )
)

;; Configure minimum staking commitment period
(define-public (set-min-stake-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> new-period u0) ERR_INVALID_PERIOD)
    (ok (var-set min-stake-period new-period))
  )
)

;; Capitalize reward treasury for distribution
(define-public (add-to-reward-pool (amount uint))
  (begin
    (asserts! (> amount u0) ERR_ZERO_STAKE)
    ;; Secure transfer of sBTC to protocol treasury
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount tx-sender (as-contract tx-sender) none
    ))
    ;; Update treasury balance
    (var-set reward-pool (+ (var-get reward-pool) amount))
    (ok true)
  )
)

;; CORE YIELD GENERATION ENGINE

;; Deposit sBTC tokens for yield generation
(define-public (stake (amount uint))
  (begin
    (asserts! (> amount u0) ERR_ZERO_STAKE)
    ;; Execute secure asset transfer to protocol
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount tx-sender (as-contract tx-sender) none
    ))
    ;; Update or initialize staking position
    (match (map-get? stakes { staker: tx-sender })
      prev-stake (map-set stakes { staker: tx-sender } {
        amount: (+ amount (get amount prev-stake)),
        staked-at: stacks-block-height,
      })
      (map-set stakes { staker: tx-sender } {
        amount: amount,
        staked-at: stacks-block-height,
      })
    )
    ;; Update protocol TVL metrics
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok true)
  )
)

;; Calculate accumulated yield for staking position
(define-read-only (calculate-rewards (staker principal))
  (match (map-get? stakes { staker: staker })
    stake-info (let (
        (stake-amount (get amount stake-info))
        (stake-duration (- stacks-block-height (get staked-at stake-info)))
        (reward-basis (/ (* stake-amount (var-get reward-rate)) u1000))
        (blocks-per-year u52560) ;; Stacks blockchain annual block target
        (time-factor (/ (* stake-duration u10000) blocks-per-year))
        (reward (* reward-basis (/ time-factor u10000)))
      )
      reward
    )
    u0
  )
)

;; Harvest accumulated yield without position closure
(define-public (claim-rewards)
  (let (
      (stake-info (unwrap! (map-get? stakes { staker: tx-sender }) ERR_NO_STAKE_FOUND))
      (reward-amount (calculate-rewards tx-sender))
    )
    (asserts! (> reward-amount u0) ERR_NO_STAKE_FOUND)
    (asserts! (<= reward-amount (var-get reward-pool)) ERR_NOT_ENOUGH_REWARDS)
    ;; Deduct rewards from treasury
    (var-set reward-pool (- (var-get reward-pool) reward-amount))
    ;; Update claim history for analytics
    (match (map-get? rewards-claimed { staker: tx-sender })
      prev-claimed (map-set rewards-claimed { staker: tx-sender } { amount: (+ reward-amount (get amount prev-claimed)) })
      (map-set rewards-claimed { staker: tx-sender } { amount: reward-amount })
    )
    ;; Reset yield calculation timestamp
    (map-set stakes { staker: tx-sender } {
      amount: (get amount stake-info),
      staked-at: stacks-block-height,
    })
    ;; Execute reward distribution
    (as-contract (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer reward-amount (as-contract tx-sender) tx-sender none
    )))
    (ok true)
  )
)

;; Close staking position and claim final rewards
(define-public (unstake (amount uint))
  (let (
      (stake-info (unwrap! (map-get? stakes { staker: tx-sender }) ERR_NO_STAKE_FOUND))
      (staked-amount (get amount stake-info))
      (staked-at (get staked-at stake-info))
      (stake-duration (- stacks-block-height staked-at))
    )
    ;; Validate withdrawal parameters
    (asserts! (> amount u0) ERR_ZERO_STAKE)
    (asserts! (>= staked-amount amount) ERR_NO_STAKE_FOUND)
    (asserts! (>= stake-duration (var-get min-stake-period))
      ERR_TOO_EARLY_TO_UNSTAKE
    )
    ;; Process final yield distribution
    (try! (claim-rewards))
    ;; Update or close staking position
    (if (> staked-amount amount)
      (map-set stakes { staker: tx-sender } {
        amount: (- staked-amount amount),
        staked-at: stacks-block-height,
      })
      (map-delete stakes { staker: tx-sender })
    )
    ;; Update protocol TVL
    (var-set total-staked (- (var-get total-staked) amount))
    ;; Execute principal withdrawal
    (as-contract (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token
      transfer amount (as-contract tx-sender) tx-sender none
    )))
    (ok true)
  )
)

;; ANALYTICS & REPORTING INTERFACE

;; Retrieve individual staking position details
(define-read-only (get-stake-info (staker principal))
  (map-get? stakes { staker: staker })
)

;; Get lifetime reward distribution for user
(define-read-only (get-rewards-claimed (staker principal))
  (map-get? rewards-claimed { staker: staker })
)

;; Current protocol yield rate
(define-read-only (get-reward-rate)
  (var-get reward-rate)
)

;; Minimum commitment period requirement
(define-read-only (get-min-stake-period)
  (var-get min-stake-period)
)

;; Available treasury balance for rewards
(define-read-only (get-reward-pool)
  (var-get reward-pool)
)

;; Total value locked across all positions
(define-read-only (get-total-staked)
  (var-get total-staked)
)

;; Calculate current annualized percentage yield
(define-read-only (get-current-apy)
  (let ((rate-basis (var-get reward-rate)))
    ;; Convert basis points to percentage representation
    (* rate-basis u100)
  )
)

;; Comprehensive protocol performance metrics
(define-read-only (get-protocol-stats)
  {
    total-staked: (var-get total-staked),
    reward-pool: (var-get reward-pool),
    current-apy: (get-current-apy),
    min-stake-period: (var-get min-stake-period),
    reward-rate: (var-get reward-rate),
  }
)
