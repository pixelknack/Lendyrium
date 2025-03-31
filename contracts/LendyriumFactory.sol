// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Lendyrium.sol";
import "./LendyriumGovernanceToken.sol";
import "./LendyriumDAO.sol";

contract LendyriumFactory {
    // Store addresses of deployed contracts
    address public governanceToken;
    address public dao;
    address public lendyrium;

    /**
     * @dev Deploys the Lendyrium ecosystem contracts without upgradeability
     * @param _oracleAddress Address of the oracle for price feeds
     * @param _judgeAddress Address of the judge for dispute resolution
     * @param _nativeToken Address of the native token used in the system
     * @return Addresses of the governance token, DAO, and Lendyrium contracts
     */
    function deployLendyrium(
        address _oracleAddress,
        address _judgeAddress,
        address _nativeToken
    ) external returns (address, address, address) {
        // Deploy the governance token
        LendyriumGovernanceToken token = new LendyriumGovernanceToken();
        governanceToken = address(token);

        // Deploy the DAO with the governance token
        LendyriumDAO daoContract = new LendyriumDAO(governanceToken);
        dao = address(daoContract);

        // Deploy the Lendyrium contract directly
        Lendyrium lendyriumContract = new Lendyrium();
        lendyrium = address(lendyriumContract);

        // Initialize the Lendyrium contract with required parameters
        lendyriumContract.initialize(dao, _oracleAddress, _judgeAddress, _nativeToken);

        // Return the addresses of the deployed contracts
        return (governanceToken, dao, lendyrium);
    }
}