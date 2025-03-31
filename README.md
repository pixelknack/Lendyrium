---
# Lendyrium Protocol Documentation

This documentation provides an in-depth look at the Lending and Borrowing protocol on Hedera, integrated with a robust Disaster Response mechanism. The documentation is divided into five detailed sections covering an overview, architecture, workflow, disaster response integration, and security with future enhancements.


## Introduction & Overview

The Lending and Borrowing protocol is designed to create a secure, decentralized financial ecosystem where merchants and borrowers can interact without intermediaries. Built on Hedera, the protocol leverages upgradeable smart contracts using OpenZeppelin’s libraries to ensure both security and flexibility. A standout feature of the protocol is the integration with a Disaster Response module, which monitors market price movements and protects borrowers in the event of significant price drops.

### Core Concepts

- **Decentralized Lending:**  
  Merchants deposit ERC20 tokens into the protocol by creating lending orders. These orders specify key parameters like interest rate, loan duration, and minimum collateral requirements. Borrowers can then secure loans by providing collateral in Ether, receiving the tokenized funds directly in their wallets.

- **Disaster Response Mechanism:**  
  Market volatility is a real risk in DeFi. The Disaster Response contract continuously monitors token prices using an external Price Oracle. If a token experiences a severe price drop (based on a predefined threshold), the disaster mode is triggered. This mechanism extends loan due dates, thereby offering borrowers extra time to manage repayments without the immediate risk of collateral liquidation.

- **Role-Based Access Control:**  
  The protocol uses role-based access control to enforce permissions:
  - **DEFAULT_ADMIN_ROLE:** Holds overarching control, typically assigned to the deployer.
  - **GOVERNOR_ROLE:** Usually allocated to the DAO, this role manages protocol-level parameters.
  - **JUDGE_ROLE:** Responsible for dispute resolution and handling exceptional circumstances.

### Use Cases and Goals

The protocol’s primary aim is to establish a trustless environment where:
- Merchants can efficiently lend tokens.
- Borrowers can secure funds with adequate collateral.
- Both parties benefit from transparent, automated processes.

Additionally, the disaster response system is designed to mitigate risks during periods of extreme market volatility. This dual approach—combining robust lending mechanisms with dynamic risk management—ensures that the system can operate smoothly even in uncertain economic conditions. The documentation below will walk through the technical and operational details that underpin this protocol, explaining how each component interacts and contributes to the overall security and efficiency of the system.

---

## Smart Contract Architecture

The protocol is built using two main smart contracts: **Lendyrium** and **DisasterResponse**. Each contract is carefully designed for modularity, upgradeability, and secure role management.

### Lendyrium Contract

#### Initialization & Roles

The `Lendyrium` contract utilizes OpenZeppelin’s `Initializable` and `AccessControlUpgradeable` libraries. Upon initialization, key addresses are set for governance, disaster response, and judicial roles. This setup is crucial because it allows for later upgrades without disrupting the state.

```solidity
function initialize(
    address _daoAddress,
    address _disasterResponseAddress,
    address _judgeAddress,
    address _nativeToken
) public initializer {
    __AccessControl_init();
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(GOVERNOR_ROLE, _daoAddress);
    _grantRole(JUDGE_ROLE, _judgeAddress);
    disasterResponse = DisasterResponse(_disasterResponseAddress);
    nativeToken = _nativeToken;
    maxInterestRate = 20;
}
```

This function ensures that administrative roles are clearly defined from the start, with the DAO and judge addresses having distinct responsibilities. The maximum interest rate is also set during initialization to control the lending parameters.

#### Order and Loan Management

Merchants create orders through the `createOrder` function. Here, they deposit ERC20 tokens into the contract, and an order is logged with details like the token address, total deposited amount, available amount, minimum collateral per unit, interest rate, and loan duration.

```solidity
function createOrder(
    address _erc20Token,
    uint256 _amount,
    uint256 _minCollateralPerUnit,
    uint256 _interestRate,
    uint256 _loanDuration
) external {
    require(_interestRate <= maxInterestRate, "Interest rate exceeds maximum");
    IERC20(_erc20Token).transferFrom(msg.sender, address(this), _amount);
    orders[nextOrderId] = MerchantOrder({
        merchant: msg.sender,
        erc20Token: _erc20Token,
        totalDeposited: _amount,
        availableAmount: _amount,
        minCollateralPerUnit: _minCollateralPerUnit,
        interestRate: _interestRate,
        loanDuration: _loanDuration
    });
    merchantOrders[msg.sender].push(nextOrderId);
    emit OrderCreated(nextOrderId, msg.sender, _erc20Token, _amount);
    nextOrderId++;
}
```

Borrowers interact with the system by calling the `borrow` function. They specify the order from which they wish to borrow, and provide the required collateral (calculated based on the order’s minimum collateral rate). On successful validation, the tokens are transferred to the borrower, and a loan record is created.

### DisasterResponse Contract

The `DisasterResponse` contract is tasked with monitoring token prices and triggering alerts if a significant price drop is detected. It integrates with a Price Oracle to fetch historical price data, allowing it to calculate the percentage change in token prices over a 24-hour window. The contract stores disaster configurations and enables the owner to register or end disaster monitoring.

```solidity
function registerPriceDisaster(
    address _token,
    address _baseToken,
    uint256 _thresholdPercentage
) external onlyOwner {
    require(_thresholdPercentage > 0 && _thresholdPercentage <= 100, "Invalid threshold");
    priceDisasters[nextDisasterId] = PriceDisaster({
        token: _token,
        baseToken: _baseToken,
        thresholdPercentage: _thresholdPercentage,
        isActive: true,
        triggeredTimestamp: 0
    });
    emit PriceDisasterTriggered(nextDisasterId, _token, 0, 0);
    nextDisasterId++;
}
```

The architecture of both contracts ensures a clear separation of concerns: the Lendyrium contract handles the financial operations while DisasterResponse manages risk mitigation. This modularity simplifies maintenance and audits, making the overall system more robust.

---

## Lending & Borrowing Workflow

The protocol’s lifecycle consists of several key phases: order creation, borrowing, repayment, and collateral claims. Each phase has specific functions, checks, and events to maintain clarity and security.

### Creating a Lending Order

Merchants kick-start the process by calling the `createOrder` function. They deposit ERC20 tokens into the contract and define the parameters for potential loans. The system then:
- Verifies that the specified interest rate does not exceed the maximum allowed.
- Transfers the tokens from the merchant to the contract.
- Creates and stores a new `MerchantOrder` structure that includes details such as token type, total deposit, available funds, and loan parameters.
- Emits an `OrderCreated` event to log the creation of the new order.

This process establishes a pool of tokens available for lending, which borrowers can access based on the order’s specific terms.

### Borrowing Funds

When a borrower decides to take out a loan, they interact with the `borrow` function. The function requires:
- Selection of an appropriate order with sufficient available funds.
- Calculation of the necessary collateral, derived from the order’s minimum collateral per unit value.
- Verification that the provided collateral (sent as Ether) meets the calculated requirement.
- Creation of a new `Loan` record that captures the loan details including borrower address, amount borrowed, collateral deposited, and timestamps marking the loan’s duration.

After these validations, the tokens are transferred from the contract to the borrower, and a `Borrowed` event is emitted. This event-driven architecture ensures that every transaction is traceable and verifiable on-chain.

### Repayment and Collateral Return

Repayment is a critical component of the protocol. Borrowers must repay both the principal and the interest accrued. The `repay` function calculates the interest based on:
- The loan’s duration (using the difference between the current time and the borrow timestamp).
- The predefined interest rate of the order.

If a disaster is active (detected by the DisasterResponse module), the due date is automatically extended by 30 days, and the transaction reverts—forcing the borrower to reattempt repayment once the extension is in place. On successful repayment:
- The principal plus interest is transferred from the borrower back to the contract.
- The collateral is returned to the borrower.
- A `Repaid` event is emitted to mark the successful completion of the loan.

In cases where the loan is not repaid on time, merchants can claim the collateral by calling `claimCollateral`. This function checks that the loan is overdue, that no disaster is active, and that the caller is indeed the merchant who created the order. Upon satisfying these conditions, the collateral is transferred to the merchant, and the loan is marked as repaid via collateral claim.

This comprehensive workflow not only automates the lending and repayment process but also integrates robust checks at every stage, ensuring that both parties are protected and that the protocol’s state remains consistent.

---

## Disaster Response Integration

Market volatility is inherent in financial systems, and the Disaster Response module is a critical component for managing such risks. This integration ensures that drastic market movements do not force hasty collateral liquidations, thereby providing a safety net for borrowers.

### Price Monitoring and Disaster Detection

The DisasterResponse contract relies on an external Price Oracle to gather historical pricing data. The core idea is to monitor the price changes over a defined window (24 hours in this implementation) and compute the percentage change between the earliest and latest prices. If the decline in price reaches or exceeds the threshold specified during disaster registration, the disaster mode is activated. This is done by evaluating:

- The **earliest** and **latest** prices within the 24-hour window.
- The absolute price difference and percentage change.
- A check ensuring that the drop meets the disaster threshold.

For example, if a token’s price drops by 50% (or any set percentage) within the window, the disaster mode is activated. This mechanism is critical as it provides a real-time signal to the lending protocol to adjust the loan terms.

### Effects on Loan Operations

Within the `repay` function of the Lendyrium contract, there is a dedicated check for disaster conditions:

```solidity
if (disasterResponse.isPriceDisasterActive(nativeToken) || 
    disasterResponse.isPriceDisasterActive(order.erc20Token)) {
    loan.dueTimestamp += 30 days; // Extend due date by 30 days
    revert("Disaster active: Due date extended");
}
```

When a disaster is detected:
- **Due Date Extension:** The borrower’s repayment window is automatically extended by 30 days, providing additional time to gather funds in volatile conditions.
- **Collateral Claim Restrictions:** The `claimCollateral` function also incorporates checks to prevent merchants from claiming collateral while a disaster is active. This ensures that borrowers are not unfairly penalized during market downturns.

### Administrative Control and Event Logging

The owner of the DisasterResponse contract has exclusive rights to register new disasters and terminate existing ones. This ensures that the activation and deactivation of disaster monitoring are controlled and deliberate actions. Each action is logged via events such as `PriceDisasterTriggered` and `PriceDisasterEnded`, allowing for transparent, on-chain auditability.

This integration of disaster response with lending operations not only protects borrowers but also adds an extra layer of sophistication to risk management in the protocol. It creates a balance between protecting borrowers from market shocks and ensuring that merchants are still incentivized to offer liquidity, as the extended due dates provide a controlled adjustment rather than an abrupt liquidation.

---

## Security Considerations & Future Enhancements

Ensuring the security of a decentralized protocol is paramount. Both the financial operations and the disaster management system must be robust against attacks and misuse. This section delves into the security practices adopted, potential vulnerabilities, and avenues for future improvements.

### Current Security Measures

- **Reentrancy Protection:**  
  Although the protocol uses low-level transfers (via `transfer`) that inherently limit gas, it is recommended to integrate OpenZeppelin’s `ReentrancyGuardUpgradeable`. This additional layer would protect against reentrancy attacks in functions like `repay` and `claimCollateral`.

- **Safe Token Operations:**  
  The protocol relies on ERC20 token transfers, which can sometimes behave unexpectedly if tokens do not strictly adhere to standards. Incorporating the SafeERC20 library from OpenZeppelin can mitigate these risks by ensuring that all token transfers are checked and handled gracefully.

- **Role-Based Access Control:**  
  The use of well-defined roles (DEFAULT_ADMIN_ROLE, GOVERNOR_ROLE, JUDGE_ROLE) ensures that only authorized entities can modify critical aspects of the protocol. This minimizes the risk of unauthorized access or malicious changes to key parameters.

- **Audit Trails and Event Logging:**  
  Every significant state change is logged through events, providing an on-chain audit trail that can be used for monitoring and debugging. These logs are crucial for maintaining transparency and building trust among users.

### Future Enhancements

- **Dynamic Interest Rates:**  
  The protocol currently uses fixed interest rates set during order creation. Future iterations could implement dynamic interest rate models that adjust based on market conditions, demand for loans, or risk metrics provided by additional oracles.

- **Improved Disaster Handling:**  
  Enhancements could include mechanisms for partial repayments during disaster periods rather than a complete revert of the transaction. A tiered disaster response system could allow for more flexible responses, such as reducing interest rates temporarily or adjusting collateral requirements dynamically.

- **Enhanced User Experience:**  
  More granular error messages and detailed revert reasons would improve the usability of the protocol. By providing borrowers and merchants with clear feedback on transaction failures, the protocol can help users quickly rectify issues.

- **Advanced Governance Mechanisms:**  
  Future updates might introduce new roles or delegate specific functions to a risk management team. This could include establishing a decentralized committee responsible for adjusting disaster thresholds based on real-time market data and community feedback.

- **Interoperability and Cross-Chain Support:**  
  As the DeFi landscape evolves, extending support for cross-chain operations might be considered. This would enable the protocol to leverage liquidity and collateral from multiple blockchain networks, further enhancing its resilience.

### Continuous Improvement and Community Engagement

The security and robustness of any DeFi protocol are not static; they require continuous audits, regular updates, and active community engagement. By inviting feedback from developers, security experts, and users, the protocol can evolve to meet emerging threats and market conditions. Regular third-party audits and bug bounty programs can further bolster the confidence of the community.

In summary, the protocol’s current design lays a strong foundation with careful consideration for both operational efficiency and security. With planned enhancements and ongoing vigilance, it is well-positioned to become a reliable, secure, and innovative lending and borrowing solution in the decentralized finance ecosystem.

---
