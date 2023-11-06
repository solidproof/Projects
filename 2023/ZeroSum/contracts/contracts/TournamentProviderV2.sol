// SPDX-License-Identifier: Unlicensed
// ZeroSum contract

pragma solidity 0.8.7;
import {FeeProvider} from "./FeeProvider.sol";
import {ITournamentProviderV2} from "./interfaces/ITournamentProviderV2.sol";
import {IBookmakerV2} from "./interfaces/IBookmakerV2.sol";
import {Initializable} from "./utils/Initializable.sol";


contract TournamentProviderV2 is FeeProvider, ITournamentProviderV2, Initializable {
    mapping(uint256 => Tournament) _tournaments;
    mapping(uint => mapping(address => Team)) _unfilledTeams;
    mapping(uint => mapping(address => bool)) _registeredPlayers;
    uint256 public minimalAdmissionFee;
    uint256 public minimalSponsorPool;
    IBookmakerV2 public BM;

    function construct(address token_, address treasury_, address wallet, address bookmaker, uint256 chainId) external override initializer onlyOwner {
        constructFeeProvider(token_, treasury_, wallet, 1000);
        minimalAdmissionFee = 1000000;
        minimalSponsorPool = 1000000;
        hash = chainId;
        BM = IBookmakerV2(bookmaker);
    }

    function setBookmaker(address bookmaker) external onlyAdmin(AdminRole.Developer) override {
            BM = IBookmakerV2(bookmaker);
    }

    function setMinimalFees(uint256 minimalAdmissionFee_, uint256 minimalSponsorPool_) external override onlyAdminHierarchy(AdminRole.Developer) {
        minimalAdmissionFee = minimalAdmissionFee_;
        minimalSponsorPool = minimalSponsorPool_;
    }

    function bTeamFilledExists(uint256 uuid, address captain, uint256 captainIndex) external view override returns(bool) {
        Tournament storage tournament = _tournaments[uuid];
        if(tournament.filledTeamCaptains.length <= captainIndex) return false;
        return tournament.filledTeamCaptains[captainIndex] == captain;
    }

    function bCanBetForTournament(uint256 uuid) external view override returns(bool) {
        Tournament storage tournament = _tournaments[uuid];
        if(tournament.status != TournamentStatus.Registration && tournament.status != TournamentStatus.Filled) return false;
        if(tournament.filledTeamCaptains.length < 2) return false;
        //TODO check time
        return true;
    }

    function getFilledTeamList(uint256 uuid) external view override returns(address[] memory captains) {
        return _tournaments[uuid].filledTeamCaptains;
    }

// ++++++++++ Registration ++++++++++
    function createTournament(uint256 fee, uint256 sponsorPool, uint256 start, uint8 playersInTeam, uint8 minTeams, uint8 maxTeams, uint16 organizerRoyalty) external override returns(bool) {
        require(fee >= minimalAdmissionFee || sponsorPool >= minimalSponsorPool, "TournamentProviderV2: Invalid admission fee or sponsor pool");
        require(minTeams >= 2 && minTeams <= maxTeams && maxTeams <= 100, "TournamentProviderV2: Invalid team count restrictions");
        require(playersInTeam > 0, "TournamentProviderV2: Invalid player in team count");
        require(organizerRoyalty <= 1000, "TournamentProviderV2: Invalid organizer royalty");
        _takeToken(msg.sender, sponsorPool);
        uint256 uuid = _nextHash();
        _tournaments[uuid] = Tournament(
            msg.sender,
            fee,
            sponsorPool,
            start,
            new address[](0),
            new address[](0),
            TournamentStatus.Registration,
            minTeams,
            maxTeams,
            playersInTeam,
            organizerRoyalty
        );
        _emitCreated(uuid, msg.sender, fee, start, organizerRoyalty, sponsorPool, playersInTeam);
        return true;
    }

    function register(uint256 uuid, address captain, address[] calldata teammates) external override returns(bool) {
        Tournament storage tournament = _tournaments[uuid];
        require(tournament.status == TournamentStatus.Registration, "TournamentProviderV2: Invalid tournament status");
        require(!_registeredPlayers[uuid][msg.sender], "TournamentProviderV2: Already registered");
        _registeredPlayers[uuid][msg.sender] = true;
        _takeToken(msg.sender, tournament.fee * (1 + teammates.length));
        Team storage team = _unfilledTeams[uuid][captain];
        if(msg.sender == captain) {
            tournament.captains.push(captain);
        }
        else {
            require(team.players.length > 0, "TournamentProviderV2: Team not exists yet");
        }
        require(team.players.length + 1 + teammates.length <= tournament.playersInTeam, "TournamentProviderV2: Too fee places in team");
        team.players.push(msg.sender);
        for(uint i = 0; i < teammates.length; i++) {
                address player = teammates[i];
                require(!_registeredPlayers[uuid][player], "TournamentProviderV2: Already registered");
                _registeredPlayers[uuid][player] = true;
                team.players.push(player);
        }
        if(team.players.length == tournament.playersInTeam) {
            tournament.filledTeamCaptains.push(team.players[0]);
            if(tournament.filledTeamCaptains.length >= tournament.maxTeams) tournament.status = TournamentStatus.Filled;
        }
        _emitRegistered(uuid, captain, msg.sender, teammates);
        return true;
    }
// ++++++++++ Pushing Results ++++++++++
    function startTournament(uint256 uuid) external onlyAdmin(AdminRole.Backend) override returns(bool) {
        Tournament storage tournament = _tournaments[uuid];
        require(tournament.status == TournamentStatus.Registration || tournament.status == TournamentStatus.Filled, "TournamentProviderV2: Invalid tournament status");
        require(tournament.filledTeamCaptains.length >= tournament.minTeams, "TournamentProviderV2: Too few teams filled");
        uint playersInTeam = tournament.playersInTeam;
        uint fee = tournament.fee;
        for(uint i = 0; i < tournament.captains.length; i++) {
            address[] memory team = _unfilledTeams[uuid][tournament.captains[i]].players;
            if(team.length < playersInTeam) {
                for(uint j = 0; j < team.length; j++) {
                    _giveToken(team[j], fee);
                }
            }
        }
        tournament.status = TournamentStatus.Started;
        _emitStarted(uuid);
        return true;
    }

    function cancelTournament(uint256 uuid) external onlyAdmin(AdminRole.Backend) override returns(bool) {
        Tournament storage tournament = _tournaments[uuid];
        require(tournament.status == TournamentStatus.Registration || tournament.status == TournamentStatus.Filled || tournament.status == TournamentStatus.Started, "TournamentProviderV2: Invalid tournament status");
        uint fee = tournament.fee;
        if(tournament.status == TournamentStatus.Started) {
            for(uint i = 0; i < tournament.filledTeamCaptains.length; i++) {
                address[] memory team = _unfilledTeams[uuid][tournament.filledTeamCaptains[i]].players;
                for(uint j = 0; j < team.length; j++) {
                    _giveToken(team[j], fee);
                }
            }
        }
        else {
            for(uint i = 0; i < tournament.captains.length; i++) {
                address[] memory team = _unfilledTeams[uuid][tournament.captains[i]].players;
                for(uint j = 0; j < team.length; j++) {
                    _giveToken(team[j], fee);
                }
            }
        }
        _giveToken(tournament.organizer, tournament.sponsorPool);
        tournament.status = TournamentStatus.Canceled;
        _emitCanceled(uuid);
        return true;
    }

    function finishTournament(uint256 uuid, uint8 feeType, address[] calldata winners, uint16[] calldata prizeFractions) override external onlyAdmin(AdminRole.Backend)  {
        Tournament storage tournament = _tournaments[uuid];
        require(tournament.status == TournamentStatus.Started, "TournamentProviderV2: Invalid tournament status");
        uint playersInTeam = tournament.playersInTeam;
        uint prizePool = tournament.fee * tournament.filledTeamCaptains.length*playersInTeam + tournament.sponsorPool;
        _sendFees(feeType, prizePool);
        prizePool -= ((prizePool * _getFees(feeType) / bpDec));
        uint left = prizePool;
        prizePool -= (tournament.organizerRoyalty * prizePool) / bpDec;
        require(winners.length == prizeFractions.length, "TournamentProviderV2: Winners length not matches prizeFractionLength");
        uint fractionSum = 0;
        for(uint i = 0; i < winners.length; i++) {
            fractionSum += prizeFractions[i];
            address[] storage team = _unfilledTeams[uuid][winners[i]].players;
            require(team.length == playersInTeam, "TournamentProviderV2: Winner team not participated in the tournament");
            uint reward = prizePool * prizeFractions[i] / (bpDec * playersInTeam);
            left -= reward * playersInTeam;
            for(uint j = 0; j < playersInTeam; j++) {
                _giveToken(team[j], reward);
            }
        }
        require(fractionSum == bpDec, "TournamentProviderV2: prizeFractions not result into 1");
        _giveToken(tournament.organizer, left);
        tournament.status = TournamentStatus.Finished;
        _emitFinished(uuid, feeType, winners);
    }
// ++++++++++ Mirror Events ++++++++++
    function _emitCreated(uint256 uuid, address organizer, uint256 fee, uint256 start, uint16 organizerRoyalty, uint256 prizePool, uint8 playersInTeam) private {
        emit TournamentCreated(uuid, organizer, fee, start, organizerRoyalty, prizePool, playersInTeam);
    }

    function _emitRegistered(uint256 uuid, address captain, address sender, address[] calldata players) private {
        emit ParticipantRegistered(uuid, captain, sender, players);
    }

    function _emitStarted(uint256 uuid) private {
        if(address(BM) != address(0)) BM.tournamentStarted(uuid);
        emit TournamentStarted(uuid);
    }

    function _emitCanceled(uint256 uuid) private {
        if(address(BM) != address(0)) BM.tournamentCanceled(uuid);
        emit TournamentCanceled(uuid);
    }

    function _emitFinished(uint256 uuid, uint8 feeType, address[] calldata winners) private {
        if(address(BM) != address(0)) BM.tournamentFinished(uuid, winners[0], feeType);
        emit TournamentFinished(uuid, winners);
    }
// ++++++++++ Utils ++++++++++
    uint256 public hash = 0;

    function _nextHash() internal returns(uint256) {
        hash = uint256(keccak256(abi.encode(hash)));
        return hash;
    }

    function setHash(uint256 newHash) external override onlyAdmin(AdminRole.Developer) {
        hash = newHash;
    }
}