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