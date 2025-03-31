// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Lendyrium.sol";
import "./LendyriumToken.sol";
import "./LendyriumDAO.sol";
import "./DisasterResponse.sol";
import "./Oracle.sol";

contract LendyriumFactory {
    struct ContractDetails {
        string name;
        address contractAddress;
        address deployer;
        uint256 deployedAt;
    }

    address public governanceToken;
    address public dao;
    address public lendyrium;
    address public oracle;
    address public disasterResponse;
    
    mapping(address => ContractDetails) public contractDetails;
    ContractDetails[] public allDeployments;

    event EcosystemDeployed(
        address governanceToken,
        address dao,
        address lendyrium,
        address oracle,
        address disasterResponse
    );

    function deployLendyrium(
        address _judgeAddress,
        address _nativeToken,
        address _initialOwner
    ) external returns (
        address, address, address, address, address
    ) {
        // Deploy PriceOracle
        PriceOracle priceOracle = new PriceOracle();
        oracle = address(priceOracle);
        _storeDetails("PriceOracle", oracle);

        // Deploy DisasterResponse
        DisasterResponse dr = new DisasterResponse(oracle);
        disasterResponse = address(dr);
        _storeDetails("DisasterResponse", disasterResponse);
        
        // Set DisasterResponse in Oracle
        priceOracle.updateDisasterResponse(disasterResponse);

        // Deploy Governance Token
        LendyriumToken token = new LendyriumToken(_initialOwner);
        governanceToken = address(token);
        _storeDetails("LendyriumToken", governanceToken);

        // Deploy DAO
        LendyriumDAO daoContract = new LendyriumDAO(governanceToken);
        dao = address(daoContract);
        _storeDetails("LendyriumDAO", dao);

        // Deploy Lendyrium main contract
        Lendyrium lendyriumContract = new Lendyrium(
            dao,
            disasterResponse,
            _judgeAddress,
            _nativeToken
        );
        lendyrium = address(lendyriumContract);
        _storeDetails("Lendyrium", lendyrium);

        // Complete setup
        dr.setLendyrium(lendyrium);
        
        // Delegate initial voting power to DAO
        token.delegate(dao);

        emit EcosystemDeployed(
            governanceToken,
            dao,
            lendyrium,
            oracle,
            disasterResponse
        );

        return (
            governanceToken,
            dao,
            lendyrium,
            oracle,
            disasterResponse
        );
    }

    function getFullEcosystemDetails() external view returns (
        ContractDetails memory priceOracle,
        ContractDetails memory disasterResponseContract,
        ContractDetails memory governanceTokenContract,
        ContractDetails memory daoContract,
        ContractDetails memory lendyriumContract,
        ContractDetails[] memory allContracts
    ) {
        return (
            contractDetails[oracle],
            contractDetails[disasterResponse],
            contractDetails[governanceToken],
            contractDetails[dao],
            contractDetails[lendyrium],
            allDeployments
        );
    }

    function _storeDetails(string memory name, address contractAddress) private {
        ContractDetails memory details = ContractDetails({
            name: name,
            contractAddress: contractAddress,
            deployer: msg.sender,
            deployedAt: block.timestamp
        });
        contractDetails[contractAddress] = details;
        allDeployments.push(details);
    }
}