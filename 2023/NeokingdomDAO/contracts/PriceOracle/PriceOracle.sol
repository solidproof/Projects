// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./IStdReference.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract PriceOracle is IStdReference, AccessControl {
    event RefDataUpdate(string symbol, uint64 rate, uint64 resolveTime);

    struct RefData {
        uint64 rate; // USD-rate, multiplied by 1e18.
        uint64 resolveTime; // UNIX epoch when data is last resolved.
    }

    mapping(string => RefData) public refs; // Mapping from symbol to ref data.
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // TODO: leave this out
        _setupRole(RELAYER_ROLE, msg.sender);
    }

    function relay(
        string[] memory _symbols,
        uint64[] memory _rates,
        uint64[] memory _resolveTimes
    ) external onlyRole(RELAYER_ROLE) {
        uint256 len = _symbols.length;
        require(_rates.length == len, "BAD_RATES_LENGTH");
        require(_resolveTimes.length == len, "BAD_RESOLVE_TIMES_LENGTH");
        for (uint256 idx = 0; idx < len; idx++) {
            refs[_symbols[idx]] = RefData({
                rate: _rates[idx],
                resolveTime: _resolveTimes[idx]
            });
            emit RefDataUpdate(_symbols[idx], _rates[idx], _resolveTimes[idx]);
        }
    }

    function getReferenceData(
        string memory _base,
        string memory _quote
    ) public view override returns (ReferenceData memory) {
        (uint256 baseRate, uint256 baseLastUpdate) = _getRefData(_base);
        (uint256 quoteRate, uint256 quoteLastUpdate) = _getRefData(_quote);
        return
            ReferenceData({
                rate: (baseRate * 1e18) / quoteRate,
                lastUpdatedBase: baseLastUpdate,
                lastUpdatedQuote: quoteLastUpdate
            });
    }

    function getReferenceDataBulk(
        string[] memory,
        string[] memory
    ) public pure override returns (ReferenceData[] memory) {
        revert("NOT_IMPLEMENTED");
    }

    function _getRefData(
        string memory _symbol
    ) internal view returns (uint256 rate, uint256 lastUpdate) {
        if (keccak256(bytes(_symbol)) == keccak256(bytes("USD"))) {
            return (1e18, block.timestamp);
        }
        RefData storage refData = refs[_symbol];
        require(refData.resolveTime > 0, "REF_DATA_NOT_AVAILABLE");
        return (uint256(refData.rate), uint256(refData.resolveTime));
    }
}
