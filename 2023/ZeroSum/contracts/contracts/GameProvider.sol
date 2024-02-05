// SPDX-License-Identifier: Unlicensed
// ZeroSum contract

pragma solidity 0.8.7;
import {FeeProvider} from "./FeeProvider.sol";
import {IGameProvider} from "./interfaces/IGameProvider.sol";
import {Initializable} from "./utils/Initializable.sol";


contract GameProvider is FeeProvider, IGameProvider, Initializable {
    mapping(uint => Game) _games;
    uint256 public minimalWager;

    function construct(address token_, address treasury_, address wallet, uint16 baseFee_, uint256 minimalWager_) external override initializer onlyOwner {
        constructFeeProvider(token_, treasury_, wallet, baseFee_);
        minimalWager = minimalWager_;
    }

    function getGame(uint256 uuid) external view override returns(Game memory game) {
        game = _games[uuid];
    }

    function setMinimalFees(uint16 minimalWager_) external override onlyAdminHierarchy(AdminRole.Developer) {
        minimalWager = minimalWager_;
    }

    function startGame(uint256 uuid, uint256 wager, address[] calldata participants) external override onlyAdmin(AdminRole.Backend) {
        require(_games[uuid].bStarted == false, "GameProvider: game already exists");
        require(participants.length > 1, "GameProvider: too few participants");
        require(participants.length < 32, "GameProvider: too many participants");
        require(wager >= minimalWager, "GameProvider: wager amount is too small");
        bytes32 rejected = 0x0;
        for(uint i = 0; i < participants.length; i++) {
            if(_takeTokenUnchecked(participants[i], wager)) {
                assembly {
                    rejected := or(add(i, 48), shl(8, rejected))
                }
            }
        }
        if(rejected != 0x0) {
            assembly {
                let ptr := mload(0x40) // Get free memory pointer
                mstore(ptr, shl(229, 4594637)) // Selector for method Error(string)
                mstore(add(ptr, 0x04), 0x20) // String offset
                mstore(add(ptr, 0x24), 32) // Revert reason length
                mstore(add(ptr, 0x44), rejected)
                revert(ptr, 0x64)
            }
        }
        _games[uuid] = Game(true, wager, participants); //TODO check for not payed
        emit GameStarted(uuid, wager, participants);
    }

    function finishGame(uint256 uuid, uint16 feeType, address winner) external override onlyAdmin(AdminRole.Backend) {
        Game storage game = _games[uuid];
        require(game.bStarted, "GameProvider: invalid game status");
        uint prizePool = game.wager * game.participants.length;
        uint winnerReward = prizePool - ((prizePool * _getFees(feeType) / bpDec));
        _giveToken(winner, winnerReward);
        _sendFees(feeType, prizePool);
        game.bStarted = false;
        address[] memory winners = new address[](1);
        winners[0] = winner;
        uint16[] memory fractions = new uint16[](1);
        fractions[0] = 10000;
        emit GameFinished(uuid, winners, fractions);
    }

    function finishGameWithPlaces(uint256 uuid, uint16 feeType, address[] calldata winners, uint16[] calldata prizeFractions) external override onlyAdmin(AdminRole.Backend) {
        Game storage game = _games[uuid];
        require(winners.length == prizeFractions.length && winners.length > 0, "GameProvider: invlaid winners length");
        require(game.bStarted, "GameProvider: invalid game status");
        uint prizePool = game.wager * game.participants.length;
        uint rewardPool = prizePool - ((prizePool * _getFees(feeType) / bpDec));
        uint left = rewardPool;
        uint fractionSum = 0;
        for(uint i = 0; i < winners.length - 1; i++) {
            uint reward = (prizeFractions[i] * rewardPool) / bpDec;
            _giveToken(winners[i], reward);
            left -= reward;
            fractionSum += prizeFractions[i];
        }
        fractionSum += prizeFractions[winners.length - 1];
        require(fractionSum == bpDec, "GameProvider: prize fractions do not result in 100%");
        _giveToken(winners[winners.length - 1], left);
        _sendFees(feeType, prizePool);
        game.bStarted = false;
        emit GameFinished(uuid, winners, prizeFractions);
    }

    function cancelGame(uint256 uuid) external override onlyAdmin(AdminRole.Backend) {
        Game storage game = _games[uuid];
        uint wager = game.wager;
        require(game.bStarted, "GameProvider: invalid game status");
        for(uint i = 0; i < game.participants.length; i++) {
            _giveToken(game.participants[i], wager);
        }
        game.bStarted = false;
        emit GameCanceled(uuid);
    }
    // +++++++++++ Utils ++++++++++
    function _takeTokenUnchecked(address from, uint256 amount) internal returns(bool){
        if(amount == 0) return false;
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, address(treasury), amount));
        if(success && (data.length == 0 || abi.decode(data, (bool)))) return false;
        return true;
    }

    event GameStarted(uint256 indexed uuid, uint256 wager, address[] participants);
    event GameCanceled(uint256 indexed uuid);
    event GameFinished(uint256 indexed uuid, address[] winners, uint16[] prizeFractions);
}