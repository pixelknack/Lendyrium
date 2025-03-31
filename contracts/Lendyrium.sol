// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DisasterResponse.sol";

contract Lendyrium is Initializable, AccessControlUpgradeable {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant JUDGE_ROLE = keccak256("JUDGE_ROLE");

    struct MerchantOrder {
        address merchant;
        address erc20Token;
        uint256 totalDeposited;
        uint256 availableAmount;
        uint256 minCollateralPerUnit;
        uint256 interestRate;
        uint256 loanDuration;
    }

    struct Loan {
        uint256 orderId;
        address customer;
        uint256 amountBorrowed;
        uint256 collateralDeposited;
        uint256 borrowTimestamp;
        uint256 dueTimestamp;
        bool isRepaid;
    }

    mapping(uint256 => MerchantOrder) public orders;
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public merchantOrders;
    mapping(address => uint256[]) public customerLoans;
    mapping(address => mapping(address => uint256)) public merchantEarnings;

    uint256 public nextOrderId;
    uint256 public nextLoanId;
    uint256 public maxInterestRate;
    uint256 public constant SECONDS_PER_YEAR = 31536000;

    DisasterResponse public disasterResponse;
    address public nativeToken;

    event OrderCreated(uint256 orderId, address merchant, address erc20Token, uint256 amount);
    event Borrowed(uint256 loanId, uint256 orderId, address customer, uint256 amount);
    event Repaid(uint256 loanId, uint256 amount);
    event CollateralClaimed(uint256 loanId, uint256 collateral);

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

    function borrow(uint256 _orderId, uint256 _amountToBorrow) external payable {
        MerchantOrder storage order = orders[_orderId];
        require(order.availableAmount >= _amountToBorrow, "Insufficient available amount");
        uint256 requiredCollateral = (_amountToBorrow * order.minCollateralPerUnit) / 1e18;
        require(msg.value >= requiredCollateral, "Insufficient collateral");
        order.availableAmount -= _amountToBorrow;
        loans[nextLoanId] = Loan({
            orderId: _orderId,
            customer: msg.sender,
            amountBorrowed: _amountToBorrow,
            collateralDeposited: msg.value,
            borrowTimestamp: block.timestamp,
            dueTimestamp: block.timestamp + order.loanDuration,
            isRepaid: false
        });
        customerLoans[msg.sender].push(nextLoanId);
        IERC20(order.erc20Token).transfer(msg.sender, _amountToBorrow);
        emit Borrowed(nextLoanId, _orderId, msg.sender, _amountToBorrow);
        nextLoanId++;
    }

    function repay(uint256 _loanId) external {
        Loan storage loan = loans[_loanId];
        require(!loan.isRepaid, "Loan already repaid");
        MerchantOrder storage order = orders[loan.orderId];

        // Check for price disaster
        if (disasterResponse.isPriceDisasterActive(nativeToken) || 
            disasterResponse.isPriceDisasterActive(order.erc20Token)) {
            loan.dueTimestamp += 30 days; // Extend due date by 30 days
            revert("Disaster active: Due date extended");
        }

        uint256 timeElapsed = block.timestamp > loan.dueTimestamp
            ? loan.dueTimestamp - loan.borrowTimestamp
            : block.timestamp - loan.borrowTimestamp;
        uint256 interest = (loan.amountBorrowed * order.interestRate * timeElapsed) / (100 * SECONDS_PER_YEAR);
        uint256 totalRepayment = loan.amountBorrowed + interest;
        IERC20(order.erc20Token).transferFrom(msg.sender, address(this), totalRepayment);
        loan.isRepaid = true;
        merchantEarnings[order.merchant][order.erc20Token] += totalRepayment;
        payable(msg.sender).transfer(loan.collateralDeposited);
        emit Repaid(_loanId, totalRepayment);
    }

       function claimCollateral(uint256 _loanId) external {
        Loan storage loan = loans[_loanId];
        require(block.timestamp > loan.dueTimestamp, "Loan not yet due");
        require(!loan.isRepaid, "Loan already repaid");
        MerchantOrder storage order = orders[loan.orderId];

        require(!disasterResponse.isPriceDisasterActive(nativeToken) && 
                !disasterResponse.isPriceDisasterActive(order.erc20Token), 
                "Cannot claim during price disaster");

        require(msg.sender == order.merchant, "Only merchant can claim");
        payable(order.merchant).transfer(loan.collateralDeposited);
        loan.isRepaid = true;
        emit CollateralClaimed(_loanId, loan.collateralDeposited);
    }

    // Function to trigger disaster check for a specific token
    function triggerDisasterCheck(uint256 _disasterId) external {
        disasterResponse.checkAndTriggerDisaster(_disasterId);
    }
}