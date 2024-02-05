//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract Coast is ERC20, ERC20Burnable {

    //Address of the $CST contract
    address public COAST = address(this);
    
    //Mom: Address which has access to...
    // read: claiming, currentVersion, unclaimed, available, claimCoast, Mom, Stacy
    // write: toggleClaiming(), newVersion(), claimableIncrease(), claimableDecrease(), claimableZero(), newStacy(), newMom()
    address internal Mom;
    
    //Stacy: Address which has access to...
    // write: claimableIncrease(), claimableDecrease(), claimableZero()
    address internal Stacy;

    //momFunction(): returns value of Mom address, only Mom address can call it
    function momFunction() public view mom_function returns(address) {
        return Mom;
    }

    //stacyFunction(): returns value of Stacy address, only Mom address can call it
    function stacyFunction() public view mom_function returns(address) {
        return Stacy;
    }
    
    
    //claiming: boolean value for if claiming $CST is turn on
    bool internal claiming = true;
    
    //currentVersion: uint value for version of which claimCoast mapping to check for user $CST allowances
    uint internal currentVersion = 0;

    //unclaimed: uint value for how much total $CST users can claim at the moment, but haven't
    //  Should always be less than available
    uint internal unclaimed = 0;

    //available: uint value for how much $CST is minted to COAST, which users can be allowed to claim
    uint internal available = 0;

    //claimingFunction(): returns value of claiming boolean, only Mom address can call it
    function claimingFunction() public view mom_function returns(bool) {
        return claiming;
    }

    //currentVersionFunction(): returns value of currentVersion uint, only Mom address can call it
    function currentVersionFunction() public view mom_function returns(uint) {
        return currentVersion;
    }

    
    //unclaimedFunction(): returns value of unclaimed uint, only Mom address can call it
    function unclaimedFunction() public view mom_function returns(uint) {
        return unclaimed;
    }

    //availableFunction(): returns value of available uint, only Mom address can call it
    function availableFunction() public view mom_function returns(uint) {
        return available;
    }

    
    //claimCoast: mapping of a uint to a mapping of an address to a uint
    //  Keeps track of how much $CST a user can claim at any point, based on the currentVersion uint
    //  claimCoast[currentVersion][userAddress] = how much $CST userAddress can claim
    mapping (uint => mapping (address => uint)) internal claimCoast;

    
    //claimCoastFunction(_claimer): returns value of claimCoast[currentVersion][_claimer], only Mom address can call it
    function claimCoastFunction(address _claimer) public view claiming_on mom_function returns(uint){
        return claimCoast[currentVersion][_claimer];
    }
    
    //constructor(): 
    //  names this contract's ERC20 accordingly
    //  sets the Mom and Stacy address to msg.sender
    constructor() ERC20("Coast", "CST") {
        Mom = msg.sender;
        Stacy = msg.sender;
    }
    
    //mom_function(): function modifier that limits access to Mom address
    modifier mom_function(){
        require(msg.sender == Mom,"Only Mom can call this function");
    _;}

    //stacy_function(): function modifier that limits acces to Stacy or Mom address
    modifier stacy_function(){
        require(msg.sender == Stacy || msg.sender == Mom,"Only Mom or Stacy can call this function");
    _;}

    //claiming_on(): function modifier that limits access to when claiming is on
    modifier claiming_on(){
        require(claiming,"Claiming is currently turned off");
    _;}

    //decimals(): sets the number of decimals for $CST
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    
    //claimable(): function which returns the amount of $CST that the caller can claim, only if claiming is on
    function claimable() public view claiming_on returns(uint){
        return claimCoast[currentVersion][msg.sender];
    }
    
    //claim(): if claiming is on...
    //  transfers callers claimable $CST to the caller
    //  updates unclaimed and available accordingly
    //  sets the callers claimable $CST to 0
    function claim() public claiming_on {

        //The caller must have some $CST to claim, otherwise it is a waste of gas
        require(claimCoast[currentVersion][msg.sender] > 0, "You aren't eligible to claim any CST");

        //_sending: uint value which keeps track of how much $CST to transfer to caller
        uint _sending = claimCoast[currentVersion][msg.sender];
        
        //sets the callers claimable $CST to 0
        claimCoast[currentVersion][msg.sender] = 0;

        //update unclaimed and available by subtracting _sending from both values
        available -= _sending;
        unclaimed -= _sending;

        //transfer $CST from the COAST contract to the caller
        _transfer(COAST, msg.sender, _sending);
    }
    
    /*** MOM FUNCTIONS ***/

    //toggleClaiming(): function that switched the value of claiming
    //  only Mom address can call it
    function toggleClaiming() public mom_function {
        claiming = !claiming;
    }

    //newVersion(): function that increments version, and resets unclaimed to 0
    //  only Mom address can call it
    function newVersion() public mom_function {
        currentVersion++;
        unclaimed = 0;
    }

    //newStacy(_stacy): function that sets the Stacy address to the new _stacy address
    //  only Mom address can call it
    function newStacy(address _stacy) public mom_function {
        Stacy = _stacy;
    }

    //newMom(_mom): function that sets the Mom address to the new _mom address
    //  only Mom address can call it
    function newMom(address _mom) public mom_function {
        Mom = _mom;
    }
    
    //mintCoast(_amount): function that mints _amount $CST to the COAST contract and updates available accordingly
    //  only Mom address can call it
    function mintCoast(uint _amount) public mom_function {
        available += _amount;
        _mint(COAST, _amount);
    }


    /*** MOM AND STACY FUNCTIONS ***/

    
    //claimIncrease(_amount, _claimer): if caller is Mom or Stacy
    //  increase amount of $CST _claimer can claim by _amount
    //  update unclaimed accordingly
    function claimableIncrease(uint _amount, address _claimer) public stacy_function {
        
        //require that there is enough $CST available for users to claim
        require(available >= unclaimed + _amount, "Mom needs to mint more Coast");
        
        //add _amount to unclaimed
        unclaimed += _amount;

        //increase users amount of claimable $CST by _amount
        claimCoast[currentVersion][_claimer] += _amount;
    }


    //claimDecrease(_amount, _claimer): if caller is Mom or Stacy
    //  decrease amount of $CST _claimer can claim by _amount
    //  update unclaimed accordingly
    function claimableDecrease(uint _amount, address _claimer) public stacy_function {
        
        //Check if _claimer can claimer more than _amount
        if (claimCoast[currentVersion][_claimer] > _amount) {
            
            //decrease claimable $CST of _claimer by _amount
            claimCoast[currentVersion][_claimer] -= _amount;
            
            //Check if unclaimed is more than _amount (it should always be, based on other checks)
            if (unclaimed > _amount) {
                //decrease unclaimed by _amount
                unclaimed = unclaimed - _amount;
            }
            else {
                //set unclaimed to 0 (this line of code should be impossible to hit)
                unclaimed = 0;
            }
        }
        //In this case, _amount is greater than or equal to how much $CST _claimer can claim
        else {
            
            //tmpClaimable: uint value which tracks how much _claimer could claim
            uint tmpClaimable = claimCoast[currentVersion][_claimer];
            
            //decrease claimable $CST for _claimer to 0
            claimCoast[currentVersion][_claimer] = 0;
            
            //Check if unclaimed is more than tmpClaimable (it should always be, based on other checks)
            if (unclaimed > tmpClaimable) {
                //decrease unclaimed by tmpClaimable
                unclaimed = unclaimed - tmpClaimable;
            }
            else {
                //setUnclaimed to 0 (this line of code should be impossible to hit)
                unclaimed = 0;
            }
        }
    }

    //claimDecrease(_claimer): if caller is Mom or Stacy
    //  set amount of $CST _claimer can claim 0
    //  update unclaimed accordingly
    function claimableZero(address _claimer) public stacy_function {
        
        //tmpClaimable: uint value which tracks how much _claimer could claim
        uint tmpClaimable = claimCoast[currentVersion][_claimer];
        
        //set claimable $CST for _claimer to 0
        claimCoast[currentVersion][_claimer] = 0;
        
        //Check if unclaimed is more than tmpClaimable (it should always be, based on other checks)
        if (unclaimed > tmpClaimable) {
            //decrease unclaimed by tmpClaimable
            unclaimed = unclaimed - tmpClaimable;
        }
        else {
            //setUnclaimed to 0 (this line of code should be impossible to hit)
            unclaimed = 0;
        }
    }

}
