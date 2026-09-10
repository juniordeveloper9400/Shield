# Member App PRD

**Product:** SHIELD member health-commerce app  
**Implementation:** Root Flutter project  
**Status:** Current-state baseline

## Problem

Members need one mobile-first place to obtain health products and services through a selected local SHIELD store, while retaining their patients, addresses, prescriptions, orders, wallet, rewards, and referrals.

## Users

- Member buying products or booking care.
- Patient/dependant represented by a member.
- Agent or investor persona detected for a signed-in member; final portal boundary is transitional.

## Goals

- Reliable Firebase phone sign-in and session restoration.
- Complete product, prescription, lab, appointment, wallet, rewards, and referral journeys.
- Clear branch selection and order/service status.
- Resilient launch when Firebase, Neon, or warmup requests are unavailable.

## In scope

Authentication, registration, branch selection, catalogue, search, cart, checkout, orders/tracking, prescription upload, labs, clinics, tele/dental/dietitian appointments, patients, addresses, wallet/privilege plans, rewards, referrals, and persona presentation.

## Acceptance outcomes

A member can sign in, select a branch, browse and buy a product, submit a prescription, book care, and inspect their resulting state without losing context after tab or app navigation.

## Release blockers

Production Android signing, iOS setup, secure handling of database access, complete catalogue seeding, and final agent/investor routing must be resolved before claiming broad production readiness.
