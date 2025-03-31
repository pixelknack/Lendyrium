// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IPriceOracle {
    function getPriceHistory(address tokenA, address tokenB, uint256 range) external view returns (uint256[] memory, uint256[] memory);
}

contract DisasterResponse is Ownable {
    IPriceOracle public priceOracle;
    uint256 public constant WINDOW_SIZE = 24 hours; // 24-hour window for price change
    uint256 public constant PRECISION = 1e18; // Precision for calculations

    struct PriceDisaster {
        address token;              // Token to monitor (native or ERC20)
        address baseToken;          // Base token for price comparison (e.g., ETH or stablecoin)
        uint256 thresholdPercentage; // Percentage decline to trigger disaster (e.g., 50 for 50%)
        bool isActive;              // Whether disaster monitoring is active
        uint256 triggeredTimestamp; // Timestamp when disaster was auto-triggered
    }

    mapping(uint256 => PriceDisaster) public priceDisasters;
    uint256 public nextDisasterId;

    event PriceDisasterTriggered(uint256 disasterId, address token, uint256 percentageDecline, uint256 timestamp);
    event PriceDisasterEnded(uint256 disasterId, uint256 timestamp);

    constructor(address _priceOracle) Ownable(msg.sender) {
        priceOracle = IPriceOracle(_priceOracle);
    }

    /**
     * @dev Register a token to monitor for a price-based disaster
     * @param _token Token to monitor
     * @param _baseToken Base token for price comparison (e.g., ETH or stablecoin)
     * @param _thresholdPercentage Percentage decline to trigger (e.g., 50 for 50%)
     */
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
        emit PriceDisasterTriggered(nextDisasterId, _token, 0, 0); // Initial registration, no trigger yet
        nextDisasterId++;
    }

    /**
     * @dev End monitoring for a specific disaster
     * @param _disasterId ID of the disaster to end
     */
    function endPriceDisaster(uint256 _disasterId) external onlyOwner {
        require(_disasterId < nextDisasterId, "Invalid disaster ID");
        priceDisasters[_disasterId].isActive = false;
        emit PriceDisasterEnded(_disasterId, block.timestamp);
    }

    /**
     * @dev Check if a price disaster is active for a token based on 24hr price change
     * @param _token Token to check
     * @return bool True if disaster is active, false otherwise
     */
    function isPriceDisasterActive(address _token) public view returns (bool) {
        for (uint256 i = 0; i < nextDisasterId; i++) {
            PriceDisaster storage disaster = priceDisasters[i];
            if (disaster.token == _token && disaster.isActive) {
                (uint256[] memory prices, uint256[] memory timestamps) = priceOracle.getPriceHistory(
                    disaster.token,
                    disaster.baseToken,
                    WINDOW_SIZE
                );

                if (prices.length < 2) continue; // Not enough data to calculate change

                // Get earliest and latest prices in the 24hr window
                uint256 earliestPrice = prices[0];
                uint256 latestPrice = prices[prices.length - 1];

                // Calculate percentage change
                int256 priceChange = int256(latestPrice) - int256(earliestPrice);
                uint256 absoluteChange = priceChange < 0 ? uint256(-priceChange) : uint256(priceChange);
                uint256 percentageChange = (absoluteChange * 100 * PRECISION) / earliestPrice;

                // Check if decline is >= 50% (i.e., change <= -50%)
                if (priceChange < 0 && percentageChange / PRECISION >= disaster.thresholdPercentage) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * @dev Auto-trigger a disaster if conditions are met (called by external contracts or keepers)
     * @param _disasterId ID of the disaster to check and potentially trigger
     */
    function checkAndTriggerDisaster(uint256 _disasterId) external {
        require(_disasterId < nextDisasterId, "Invalid disaster ID");
        PriceDisaster storage disaster = priceDisasters[_disasterId];
        require(disaster.isActive && disaster.triggeredTimestamp == 0, "Disaster already triggered or inactive");

        (uint256[] memory prices, uint256[] memory timestamps) = priceOracle.getPriceHistory(
            disaster.token,
            disaster.baseToken,
            WINDOW_SIZE
        );

        if (prices.length < 2) return; // Not enough data

        uint256 earliestPrice = prices[0];
        uint256 latestPrice = prices[prices.length - 1];
        int256 priceChange = int256(latestPrice) - int256(earliestPrice);
        uint256 absoluteChange = priceChange < 0 ? uint256(-priceChange) : uint256(priceChange);
        uint256 percentageChange = (absoluteChange * 100 * PRECISION) / earliestPrice;

        if (priceChange < 0 && percentageChange / PRECISION >= disaster.thresholdPercentage) {
            disaster.triggeredTimestamp = block.timestamp;
            emit PriceDisasterTriggered(_disasterId, disaster.token, percentageChange / PRECISION, block.timestamp);
        }
    }
}