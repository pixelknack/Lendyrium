// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/safeMath.sol";


contract LendyriumToken is Ownable {
    using SafeMath for uint;

    string public constant name = "Lendyrium Token";
    string public constant symbol = "LT";
    uint8 public constant decimals = 18;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    
    // Voting power tracking
    mapping(address => uint) public votingPower;
    uint public totalVotingPower;
    
    // EIP-712 permit support
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = 
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public nonces;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    constructor(address initialOwner) Ownable(initialOwner) {
        uint chainId = block.chainid;
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
        _mint(initialOwner, 1000000 * 10 ** decimals);
    }

    // Core ERC20 functions
    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        _moveVotingPower(address(0), to, value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        _moveVotingPower(from, address(0), value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        _moveVotingPower(from, to, value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    // EIP-2612 permit function
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, "LT: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, "LT: INVALID_SIGNATURE");
        _approve(owner, spender, value);
    }

    // Voting power delegation
    function delegate(address delegatee) external {
        _delegate(msg.sender, delegatee);
    }

    function _delegate(address delegator, address delegatee) internal {
        uint currentBalance = balanceOf[delegator];
        _moveVotingPower(delegator, delegatee, currentBalance);
        emit DelegateChanged(delegator, delegator, delegatee);
    }

    function _moveVotingPower(address src, address dst, uint amount) internal {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                uint oldWeight = votingPower[src];
                votingPower[src] = oldWeight.sub(amount);
                emit DelegateVotesChanged(src, oldWeight, votingPower[src]);
            }
            if (dst != address(0)) {
                uint oldWeight = votingPower[dst];
                votingPower[dst] = oldWeight.add(amount);
                emit DelegateVotesChanged(dst, oldWeight, votingPower[dst]);
            }
        }
    }

    // SafeMath library (inline to avoid external dependency)
    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint a, uint b) internal pure returns (uint) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }
}