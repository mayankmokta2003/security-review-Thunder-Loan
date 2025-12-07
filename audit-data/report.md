---
title: Thunder Loan Security Report
author: MayankMokta
date: December 7, 2025
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
        \includegraphics[width=0.5\textwidth]{logo.png} 
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries Protocol Audit Report\par}
    \vspace{1cm}
    {\Large Version 1.0\par}
    \vspace{2cm}
    {\Large\itshape Cyfrin.io\par}
    \vfill
    {\large \today\par}
\end{titlepage}

\maketitle

<!-- Your report starts here! -->

Prepared by: [Mayank]
Lead Auditors: 
- Mayank Mokta

# Table of Contents
- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
- [High](#high)
- [Medium](#medium)
- [Low](#low)
- [Informational](#informational)
- [Gas](#gas)

# Protocol Summary

1. This protocol kind of uses the concept of Aave or compound.
2. In this protocol a user can deposit the approved token and can get a bit of interest.
3. Users can take a loan from this contract by depositing some collateral and have to pay back with a bit of interest.
4. Even users can take a flashloan from this protocol.

# Disclaimer

I Mayank Mokta made all the effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by me is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details 

**Below we have our commit hash**

```

```


## Scope 

```
./src/protocol/ThunderLoan.sol
./src/protocol/AssetToken.sol
```


## Roles

- Owner: The ownerof the contract who can decide which tokens should be allowed to deposit.
- Liquidator: The users who provide liquidity to the contract and earns profit.
- Users: users who can take loans or flash loan from this protocol.


# Executive Summary

I just loved auditing this codebase, currently in my beginner learing phase and i learned a lot of new things auditing this codebase.


## Issues found

| Severity | Number of issues found |
| -------- | ---------------------- |
| HIGH     | 3                      |
| MEDIUM   | 3                      |
| LOW      | 1                      |
| INFO     | 7                      |
| GAS      | 3                      |
| TOTAL    | 17                     |


# Findings
# High
# Medium
# Low 
# Informational
# Gas 