// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.25;

contract SimpleERC20 {
    string public name = "USDC";
    string public symbol = "USDC";
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        address from = msg.sender;
        require(balanceOf[from] >= amt, "insuf");
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        emit Transfer(from, to, amt);
        return true;
    }
}