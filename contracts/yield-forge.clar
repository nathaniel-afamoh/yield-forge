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