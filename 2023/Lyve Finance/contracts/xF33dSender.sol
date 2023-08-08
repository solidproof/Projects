// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {ILayerZeroEndpoint} from "./interfaces/ILayerZeroEndpoint.sol";
import {ILayerZeroReceiver} from "./interfaces/ILayerZeroReceiver.sol";

import {IxF33dAdapter} from "./interfaces/IxF33dAdapter.sol";
import {IxF33dReceiver} from "./interfaces/IxF33dReceiver.sol";

/**
 * @title xF33dSender
 * @author sarangparikh22
 * @dev This contract allows for the creation and deployment of feeds, as well as the sending of updated rates to those feeds.
 * The contract uses the LayerZero protocol to send messages between chain.
 */
contract xF33dSender is Ownable2Step, ILayerZeroReceiver {
    ILayerZeroEndpoint public lzEndpoint;
    mapping(bytes32 => address) public activatedFeeds;
    mapping(uint16 => address) public remoteSrcAddress;
    mapping(bytes32 => bytes) public protectedFeeds;
    uint16 public chainId;

    constructor(address _endpoint, uint16 _chainId) {
        lzEndpoint = ILayerZeroEndpoint(_endpoint);
        chainId = _chainId;
    }

    event SentUpdatedRate(
        uint16 _chainId,
        address _feed,
        bytes _feedData,
        bytes _payload
    );
    event FeedDeployed(
        uint16 _chainId,
        address _feed,
        bytes _feedData,
        address receiver
    );
    event FeedActivated(bytes32 _feedId, address _receiver);
    event SetRemoteSrcAddress(uint16 _chainId, address _remoteSrcAddress);
    event SetProtectedFeeds(uint16 _chainId, address _feed);
    event SetLzEndpoint(address _lzEndpoint);

    /**
     * @dev This function sends an updated rate to a feed.
     * @param _chainId The chain ID of the feed.
     * @param _feed The address of the feed.
     * @param _feedData The data for the feed.
     */
    function sendUpdatedRate(
        uint16 _chainId,
        address _feed,
        bytes calldata _feedData
    ) external payable {
        bytes32 _feedId = keccak256(abi.encode(_chainId, _feed, _feedData));
        address _receiver = activatedFeeds[_feedId];
        require(_receiver != address(0), "feed not active");
        // Get the latest data for the feed.
        bytes memory _payload = IxF33dAdapter(_feed).getLatestData(_feedData);

        // Send the updated rate to the feed using the LayerZero protocol.
        require(msg.value > 0,"msg.value zero") ;
        lzEndpoint.send{value: msg.value}(
            _chainId,
            abi.encodePacked(_receiver, address(this)),
            _payload,
            payable(msg.sender),
            address(0),
            bytes("")
        );

        emit SentUpdatedRate(_chainId, _feed, _feedData, _payload);
    }

    /**
     * @dev This function deploys a new feed.
     * @param _chainId The chain ID of the feed.
     * @param _feed The address of the feed.
     * @param _feedData The data for the feed.
     * @param _bytecode The bytecode for the feed receiver contract.
     * @return The address of the deployed feed receiver contract.
     */
    function deployFeed(
        uint16 _chainId,
        address _feed,
        bytes calldata _feedData,
        address _lsdRateOracle,
        bytes memory _bytecode
    ) external payable returns (address) {
        require(_chainId != 0,"error chainId") ;
        require(_feed != address(0),"null address") ;
        require(_lsdRateOracle != address(0),"null address") ;        
        if (protectedFeeds[keccak256(abi.encode(_chainId, _feed))].length > 0)
            _bytecode = protectedFeeds[keccak256(abi.encode(_chainId, _feed))];

        // Create the feed contract.
        bytes32 salt = keccak256(
            abi.encode(_chainId, _feed, _feedData, _bytecode)
        );

        address receiver;

        assembly {
            receiver := create2(0, add(_bytecode, 0x20), mload(_bytecode), salt)

            if iszero(extcodesize(receiver)) {
                revert(0, 0)
            }
        }
        
        require(remoteSrcAddress[_chainId] != address(0),"error remoteSrcAddress") ;
        // Initialize the feed contract.
        IxF33dReceiver(receiver).init(
            address(lzEndpoint),
            remoteSrcAddress[_chainId],
            _lsdRateOracle
        );
        // Send a message to the remote chain to indicate that the feed has been deployed.
        require(msg.value > 0,"msg.value zero") ;
        lzEndpoint.send{value: msg.value}(
            _chainId,
            abi.encodePacked(remoteSrcAddress[_chainId], address(this)),
            abi.encode(
                keccak256(abi.encode(chainId, _feed, _feedData)),
                receiver
            ),
            payable(msg.sender),
            address(0),
            bytes("")
        );

        emit FeedDeployed(_chainId, _feed, _feedData, receiver);

        return receiver;
    }

    /**
     * @dev Receives a message from LayerZero.
     * @param _chainId The ID of the chain that the message came from.
     * @param _srcAddress The address of the sender on the chain that the message came from.
     * @param _payload The message payload.
     */
    function lzReceive(
        uint16 _chainId,
        bytes memory _srcAddress,
        uint64,
        bytes calldata _payload
    ) public virtual override {
        require(msg.sender == address(lzEndpoint),"not lzEndpoint");
        address remoteSrc;
        assembly {
            remoteSrc := mload(add(_srcAddress, 20))
        }
        require(remoteSrc == remoteSrcAddress[_chainId],"not trustAddress");
        (bytes32 _feedId, address _receiver) = abi.decode(
            _payload,
            (bytes32, address)
        );

        activatedFeeds[_feedId] = _receiver;

        emit FeedActivated(_feedId, _receiver);
    }

    /**
     * @dev Sets the remote source address for the specified chain.
     * @param _chainId The chain ID of the remote chain.
     * @param _remoteSrcAddress The address of the remote source contract.
     */
    function setRemoteSrcAddress(
        uint16 _chainId,
        address _remoteSrcAddress
    ) external onlyOwner {
        remoteSrcAddress[_chainId] = _remoteSrcAddress;
        emit SetRemoteSrcAddress(_chainId, _remoteSrcAddress);
    }

    /**
     * @dev Sets the bytecode for a protected feed.
     * @param _chainId The chain ID of the feed.
     * @param _feed The address of the feed.
     * @param _bytecode The bytecode for the feed receiver contract.
     */
    function setProtectedFeeds(
        uint16 _chainId,
        address _feed,
        bytes calldata _bytecode
    ) external onlyOwner {
        protectedFeeds[keccak256(abi.encode(_chainId, _feed))] = _bytecode;
        emit SetProtectedFeeds(_chainId, _feed);
    }

    /**
     * @dev Sets the LayerZero endpoint for the contract.
     * @param _lzEndpoint The address of the LayerZero endpoint.
     */
    function setLzEndpoint(address _lzEndpoint) external onlyOwner {
        lzEndpoint = ILayerZeroEndpoint(_lzEndpoint);
        emit SetLzEndpoint(_lzEndpoint);
    }

    /**
     * @dev Returns the estimated fees for updating a rate.
     * @param _chainId The ID of the chain.
     * @param _feed The address of the feed.
     * @param _feedData The data to update the rate with.
     * @return fees The estimated fees for the update.
     */
    function getFeesForRateUpdate(
        uint16 _chainId,
        address _feed,
        bytes calldata _feedData
    ) external view returns (uint256 fees) {
        bytes memory _payload = IxF33dAdapter(_feed).getLatestData(_feedData);
        (fees, ) = lzEndpoint.estimateFees(
            _chainId,
            address(this),
            _payload,
            false,
            bytes("")
        );
    }

    /**
     * @dev Returns the estimated fees for deploying a feed.
     * @param _chainId The ID of the chain.
     * @param _feed The address of the feed.
     * @param _feedData The data to deploy the feed with.
     * @return fees The estimated fees for the deployment.
     */
    function getFeesForDeployFeed(
        uint16 _chainId,
        address _feed,
        bytes calldata _feedData
    ) external view returns (uint256 fees) {
        (fees, ) = lzEndpoint.estimateFees(
            _chainId,
            address(this),
            abi.encode(
                keccak256(abi.encode(chainId, _feed, _feedData)),
                address(0)
            ),
            false,
            bytes("")
        );
    }
}
