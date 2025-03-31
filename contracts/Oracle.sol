// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PriceOracle {
    struct PriceEntry {
        uint256 timestamp;
        uint256 price;
    }

    address public disasterResponse;
    address public owner;

    mapping(address => PriceEntry[]) public tokenPrices;
    PriceEntry[] public nativePrices;

    event PriceUpdated(bool isNative, address token, uint256 price);
    event DisasterResponseUpdated(address newDisasterResponse);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyDisasterResponse() {
        require(msg.sender == disasterResponse, "Unauthorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Add this new function
    function setDisasterResponse(address _disasterResponse) external onlyOwner {
        disasterResponse = _disasterResponse;
        emit DisasterResponseUpdated(_disasterResponse);
    }

    function updateTokenPrice(
        address token,
        uint256 price
    ) external onlyDisasterResponse {
        tokenPrices[token].push(PriceEntry(block.timestamp, price));
        emit PriceUpdated(false, token, price);
    }

    function updateNativeTokenPrice(
        uint256 price
    ) external onlyDisasterResponse {
        nativePrices.push(PriceEntry(block.timestamp, price));
        emit PriceUpdated(true, address(0), price);
    }

    function getHistoricalPrice(
        bool isNative,
        address token,
        uint256 timestamp
    ) external view returns (uint256) {
        PriceEntry[] storage entries = isNative
            ? nativePrices
            : tokenPrices[token];
        for (uint i = entries.length; i > 0; i--) {
            if (entries[i - 1].timestamp <= timestamp) {
                return entries[i - 1].price;
            }
        }
        return 0;
    }

    function updateDisasterResponse(
        address _disasterResponse
    ) external onlyOwner {
        disasterResponse = _disasterResponse;
        emit DisasterResponseUpdated(_disasterResponse);
    }
}
