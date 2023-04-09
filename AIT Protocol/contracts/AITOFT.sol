pragma solidity ^0.8.0;
import "./token/oft/OFT.sol";

contract AITOFT is OFT {
    constructor(address _lzEndpoint) OFT("AIT Protocol", "AIT", _lzEndpoint){}
}