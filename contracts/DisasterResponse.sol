// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Oracle.sol";

contract DisasterResponse is Ownable {
    struct PriceData {
        uint256 timestamp;
        uint256 price;
    }

    PriceOracle public priceOracle;
    address public lendyrium;
    
    mapping(address => bool) public tokenDisasters;
    bool public nativeDisaster;
    uint256 public constant DISASTER_THRESHOLD = 50;

    event DisasterActivated(bool isNative, address token);
    event DisasterDeactivated(bool isNative, address token);

    constructor(address _priceOracle) Ownable(msg.sender) {
        priceOracle = PriceOracle(_priceOracle);
    }

    modifier onlyLendyrium() {
        require(msg.sender == lendyrium, "Only Lendyrium");
        _;
    }

    function setLendyrium(address _lendyrium) external onlyOwner {
        lendyrium = _lendyrium;
    }

    function checkAndTriggerDisaster(bool isNative, address token, uint256 currentPrice) external onlyLendyrium {
        uint256 pastPrice = priceOracle.getHistoricalPrice(isNative, token, block.timestamp - 24 hours);
        if (pastPrice == 0) return;

        uint256 decline = ((pastPrice - currentPrice) * 100) / pastPrice;
        bool disasterStatus = decline >= DISASTER_THRESHOLD;

        if (isNative) {
            if (nativeDisaster != disasterStatus) {
                nativeDisaster = disasterStatus;
                if (disasterStatus) {
                    emit DisasterActivated(true, address(0));
                } else {
                    emit DisasterDeactivated(true, address(0));
                }
            }
        } else {
            if (tokenDisasters[token] != disasterStatus) {
                tokenDisasters[token] = disasterStatus;
                if (disasterStatus) {
                    emit DisasterActivated(false, token);
                } else {
                    emit DisasterDeactivated(false, token);
                }
            }
        }
    }

    function isPriceDisasterActive(bool isNative, address token) external view returns (bool) {
        return isNative ? nativeDisaster : tokenDisasters[token];
    }
}