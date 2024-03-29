// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IProtocolFees} from "./interfaces/IProtocolFees.sol";

contract ProtocolFees is IProtocolFees, OwnableUpgradeable {
  /// @dev The protocol fee multiplier -- the owner can update this field.
  /// @return 0 Gas multplier.
  uint256 public protocolFeeMultiplier;

  /// @dev The protocol fixed fee multiplier -- the owner can update this field.
  /// @return 0 fixed fee.
  uint256 public protocolFixedFee;

  /// @dev The address of the registered protocolFeeCollector contract -- the owner can update this field.
  /// @return 0 Contract to forward protocol fees to.
  address public protocolFeeCollector;

  function __ProtocolFees_init() public onlyInitializing {
    __Ownable_init();
  }

  /// @dev Allows the owner to update the protocol fee multiplier.
  /// @param updatedProtocolFeeMultiplier The updated protocol fee multiplier.
  function setProtocolFeeMultiplier(
    uint256 updatedProtocolFeeMultiplier
  ) external override onlyOwner {
    emit ProtocolFeeMultiplier(
      protocolFeeMultiplier,
      updatedProtocolFeeMultiplier
    );
    protocolFeeMultiplier = updatedProtocolFeeMultiplier;
  }

  /// @dev Allows the owner to update the protocol fixed fee.
  /// @param updatedProtocolFixedFee The updated protocol fixed fee.
  function setProtocolFixedFee(
    uint256 updatedProtocolFixedFee
  ) external override onlyOwner {
    emit ProtocolFixedFee(protocolFixedFee, updatedProtocolFixedFee);
    protocolFixedFee = updatedProtocolFixedFee;
  }

  /// @dev Allows the owner to update the protocolFeeCollector address.
  /// @param updatedProtocolFeeCollector The updated protocolFeeCollector contract address.
  function setProtocolFeeCollectorAddress(
    address updatedProtocolFeeCollector
  ) external override onlyOwner {
    emit ProtocolFeeCollectorAddress(
      protocolFeeCollector,
      updatedProtocolFeeCollector
    );
    protocolFeeCollector = updatedProtocolFeeCollector;
  }
}
