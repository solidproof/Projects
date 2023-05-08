// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../token/WonkaCapital.sol";
/* interface WonkaCapital {
	function getVestingFee(address addr) external view returns (uint256);
	function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
	function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
} */
/*
* @title ERC721 token for WonkaBronze
*
* @author WonkaBronze
*/
contract WonkaBronze is ERC721, Ownable, ERC721Enumerable {
    
	using Strings for uint256;
	using SafeMath for uint256;
	
    uint256 public mintprice 		= 	1 ether;
    address public multisigWallet	=	0x32Aae574798d85D7C21135d2882f3B97fC43eFA3;
    uint256 public totalWithdrawAmount;

    using Counters for Counters.Counter;
    Counters.Counter private tokenCounter;
	
	WonkaCapital private wonkacapital;
	
	string public ipfsURI;
    uint256 constant MAX_SUPPLY 						= 	3000;
    uint256 public constant REWARD_PER_NFT_PER_WEEK 	= 	300000 * 1e9;
    uint256 public constant REWARD_PERIOD 				= 	1 weeks;
    uint256 public TOTAL_WEEKS 							= 	52;
	
	struct rewardData{
        uint256 totalWeeksWithdraw;
        uint256 lastWithdraw;
        uint256 totalWithdrawAmount;
    }
	mapping(uint256 => rewardData) public _reward_data;
	mapping(address => uint256) public _user_data;
	
	event rewardWithdrawed(address _addr, uint256 _amount, uint256 _periods);
    /**
    * @notice Constructor to create contract
    *
    * @param _name the token Name
    * @param _symbol the token Symbol
    */
    constructor (
        string memory _name,
        string memory _symbol,
        string memory _ipfsURI,
		address _tokenAddress
    ) ERC721(_name, _symbol) {
        ipfsURI = _ipfsURI;
		wonkacapital = WonkaCapital(_tokenAddress);
    }

    /**
    * @notice Mint New Token for Public
    */
    function mint() external payable {
		
		require(tokenCounter.current() < MAX_SUPPLY, "All NFT Minted");
		require(balanceOf(_msgSender()) < 1, "You already have 1 NFT");
		
        if (owner()==_msgSender()) {// only admin can mint
            _mintToken(1, _msgSender());
        }else{
            _collectFeeAndMintToken(1);
        }
    }

    /**
    * @notice collectAmount
    *
    * @param _quantity Total Tokens to mint
    * @param _addr User Address
    */
    function collectAmount(uint256 _quantity, address _addr) internal {

        uint256 amount = mintprice * _quantity;
        require(msg.value >= amount, "Amount sent is not enough");

        // send excess Payment return
        uint256 excessPayment = msg.value - amount;
        if (excessPayment > 0) {
            (bool returnExcessStatus,) = payable(_addr).call{value : excessPayment}("");
            require(returnExcessStatus, "Error returning excess payment");
        }
        (bool returnAdminStatus,) = payable(multisigWallet).call{value : amount}("");
        require(returnAdminStatus, "Error sending payment to admin");
    }

    /**
    * @notice Mint Tokens
    *
    * @param _addr User Address
    */
    function _mintToken(uint256 _quantity, address _addr) internal {
		
		for (uint256 i = 1; i <= _quantity; i++) {
            tokenCounter.increment();
			_reward_data[tokenCounter.current()].totalWeeksWithdraw		=	0;	
			_reward_data[tokenCounter.current()].totalWithdrawAmount	=	0;	
			_reward_data[tokenCounter.current()].lastWithdraw	=	block.timestamp;
			_user_data[_addr]	=	tokenCounter.current();
            _mint(_addr, tokenCounter.current());
        }
    }

    /**
    * @notice _CollectFeeAndMintToken
    *
    * @param _quantity Total tokens to mint
    */
    function _collectFeeAndMintToken(uint256 _quantity) internal {

        collectAmount(_quantity, _msgSender());
        _mintToken(_quantity, _msgSender());
    }

    /**
    * @notice Configure Mint Price
    *
    * @param _mintprice Mint Price
    */
    function setMintPrice(uint256 _mintprice) external onlyOwner {
        mintprice = _mintprice;
    }

    /**
    * @notice Configure Multisig Wallet
    *
    * @param _multisigWallet Address
    */
    function setMultisigWallet(address _multisigWallet) external onlyOwner {
        multisigWallet = _multisigWallet;
    }
	
	/**
    * @notice Check baseURI for token
    */
    function _baseURI() internal view override returns (string memory) {
		return ipfsURI;
    }
	
	/**
     * @dev See {IERC721Metadata-tokenURI}.
     *
    */
    function tokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = _baseURI();
		return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI)) : "";
    }
	
	/**
    * @notice Change the base URI for returning metadata
    * 
    * @param _ipfsURI the respective base URI
    */
    function setBaseURI(string memory _ipfsURI) external onlyOwner {
		ipfsURI 			= 	_ipfsURI; 
    }
	
	/**
    * @notice Change Reward weeks
    * 
    * @param _TOTAL_WEEKS the respective number of weeks
    */
    function setTotalWeeks(uint256 _TOTAL_WEEKS) external onlyOwner {
		TOTAL_WEEKS 			= 	_TOTAL_WEEKS; 
    }
	
	/**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721) {
		require(balanceOf(to) < 1, "User already have 1 NFT");
		delete _user_data[from];
		_user_data[to]		=	tokenId;
        super._transfer(from, to, tokenId);
    }
	
	/**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
	
	/**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
	
	function updateReward(uint256 _tokenid) internal returns (uint256, uint256){
		
		(uint256 bonus, uint256 periods)			=	getRewardBonus(_tokenid);
		if(bonus>0){
			_reward_data[_tokenid].lastWithdraw		=	block.timestamp;
			_reward_data[_tokenid].totalWeeksWithdraw	+=	periods;
		}
		return (bonus, periods);
	}
	
    function withdrawReward() external {
		
		if(wonkacapital.balanceOf(address(this))>0){
			address  _addr	=  _msgSender();
			if(_user_data[_addr]>0){
				(uint256 bonus, uint256 periods)	=	updateReward(_user_data[_addr]);
				if(bonus > 0 && wonkacapital.transfer(_addr, bonus)){
					_reward_data[_user_data[_addr]].totalWithdrawAmount	+=	bonus;
					totalWithdrawAmount	+=	bonus;
					emit rewardWithdrawed(_addr, bonus, periods);
				}else{
					revert("Unable to transfer funds");
				}
			}
		}else{
			revert("No enough balance");
		}
    }
	
	function getUserRewardInfo() public view returns (uint256, uint256, uint256, uint256, uint256, uint256){
		
		address  _addr						=  	_msgSender();
		uint256 _tokenid 					=	_user_data[_addr];
		(uint256 bonus, uint256 periods)	=	getRewardBonus(_tokenid);
		
		uint256 nextWithdraw	=	_reward_data[_tokenid].lastWithdraw.add(REWARD_PERIOD);
		uint256 timeRemaining 	= 	0;
		if(nextWithdraw > block.timestamp){
			timeRemaining 		= 	nextWithdraw.sub(block.timestamp);
		}
		return (_reward_data[_tokenid].totalWeeksWithdraw, _reward_data[_tokenid].lastWithdraw, timeRemaining, periods, _reward_data[_tokenid].totalWithdrawAmount, bonus);
    }
	
    function getRewardBonus(uint256 _tokenid) public view returns (uint256, uint256){
		
		uint256 total_period = block.timestamp.sub(_reward_data[_tokenid].lastWithdraw);
        uint256 periods 	= 	total_period.div(REWARD_PERIOD);
		if(_reward_data[_tokenid].totalWeeksWithdraw+periods > TOTAL_WEEKS){
			periods	=	TOTAL_WEEKS - _reward_data[_tokenid].totalWeeksWithdraw;
		}
		if(periods>0){
			return (periods * REWARD_PER_NFT_PER_WEEK, periods);
		}else{
			return (0, 0);
		}
	}
	
	function getRewardInfo(uint256 _tokenid) public view returns (rewardData memory){
		
		return _reward_data[_tokenid];
	}
	
	function getBalance() internal view returns (uint256){
        return wonkacapital.balanceOf(address(this));
    }
}