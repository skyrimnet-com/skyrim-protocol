pragma solidity ^0.4.26;

import "./Owned.sol";
import "./SNSToken.sol";

contract SNSSynth is ERC20Token {
    using SafeMath for uint256;

    //mint & burn event
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    uint256 public mintingRate;

    SNS private _snsToken;

    //locked SNS amount
    mapping(address => uint256) public internalSNSBalance;

    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(address _issuer, address snsToken, string _name, string _symbol, uint8 _decimals) public Owned(_issuer){
        _snsToken = SNS(snsToken);

        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        totalSupply = uint256(0);
        balances[_issuer] = uint256(0);

        mintingRate = 0;
    }

    /**
     * @dev synthetic assets minting rate setting up
     * @param newRate The minting rate.
     */
    function setMintingRate(uint256 newRate) public {
        require(newRate != 0);
        mintingRate = newRate;
    }

    /**
     * @dev This method will lock SNS token to mint synthetic assets
     * @param _amount The amount of synthetic assets you want to mint.
     */
    function mint(uint256 _amount) public {
        address user = msg.sender;

        //check rate
        require(mintingRate != 0);

        //check user balance
        uint256 userSNSBalance = _snsToken.balanceOf(user);
        uint256 snsCost = _amount.mul(mintingRate);
        require(snsCost <= userSNSBalance);

        //transfer from user balance to this contract
        _snsToken.transferFrom(user, address(this), snsCost);

        //record user sns cost to balance map
        internalSNSBalance[user] = internalSNSBalance[user].add(snsCost);

        //mint synthetic assets to user
        _mintAssets(user, _amount);
    }


    /**
     * @dev This method will burn synthetic assets to redeem SNS token
     * @param _snsAmount The amount of SNS tokens you want to redeem.
     */
    function redeem(uint256 _snsAmount) public {
        address user = msg.sender;

        //check rate
        require(mintingRate != 0);

        //check sns internal balance
        uint256 snsBalance = internalSNSBalance[user];
        require(snsBalance >= _snsAmount, "too greed");

        //check synthetic assets balance
        uint256 synBalance = balanceOf(user);
        uint256 synBurnAmount = _snsAmount.div(mintingRate);
        require(synBalance >= synBurnAmount, "insufficient synthetic assets balance");

        //burn and unlock the balance
        _burnAssets(user, synBurnAmount);

        _snsToken.transfer(user, _snsAmount);
        internalSNSBalance[user] = internalSNSBalance[user].sub(_snsAmount);
    }


    /**
     * @dev mint synthetic token.
     * @param _to The address which assets mint to.
     * @param _amount The synthetic token mint amount.
     */
    function _mintAssets(address _to, uint256 _amount) private returns (bool) {
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);

        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    /**
     * @dev Burn synthetic token when address redeem SNS token.
     * @param _from The address which assets mint to.
     * @param _amount The synthetic token mint amount.
     */
    function _burnAssets(address _from, uint256 _amount) private returns (bool) {
        balances[_from] = balances[_from].sub(_amount);
        totalSupply = totalSupply.sub(_amount);

        emit Burn(_from, _amount);
        emit Transfer(_from, address(0), _amount);

        return true;
    }
}
